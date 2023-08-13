terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.7.0" 
    }
  }
}

locals {
  outside_cidr_block = "0.0.0.0/0"
}

#_----------------------------------------
###################
#    Providers    #
###################
#_----------------------------------------
provider "aws" {
  region = "us-east-1"
}
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token

}
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name

} 

#_----------------------------------------
#################################
# Creating VPC and EKS and ECR  #
################################
#_----------------------------------------


# Get the availability zones of certain region
data "aws_availability_zones" "available" {}

# Creating vpc and subnets 
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name                 = var.vpc_name
  cidr                 = var.vpc_cidr_block
  azs                  = data.aws_availability_zones.available.names
  private_subnets = var.public_subnet_ips
  public_subnets  = var.private_subnet_ips
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  tags =  {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    Name = "${var.vpc_name}-vpc"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"  # The annotation used by cluster for acknowledgment
    "kubernetes.io/role/elb"                      = "1"
    Name = "${var.vpc_name}-public_subnets"

  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
    Name = "${var.vpc_name}-private_subnets"
  }
}

# Create full eks cluster with eks managed nodes 
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.27"
  subnet_ids      = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets
  vpc_id          = module.vpc.vpc_id
  cluster_addons = {
    coredns = {
      recent = true
    }
    kube-proxy = {
      recent = true  

    }
    vpc-cni = {
      recent = true

    }
  }  
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = false
  manage_aws_auth_configmap = true
  aws_auth_users = [ # Added iam-role of jenkins instance to authorized users to let it connect with cluster
    {
      userarn  = aws_iam_role.jenkins-role.arn
      username = aws_iam_role.jenkins-role.name
      groups   = ["system:masters"]
    }
  ]
  eks_managed_node_groups = {
    first = {
      desired_size = 2
      max_size     = 10
      min_size     = 1
      instance_types = ["t2.small"]
    }
  }
  node_security_group_additional_rules = {  # Allowed all traffic for node to node connection, It's easy for ingress
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = { 
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }


}

# Adding policies to worker nodes to pull from ECR 
resource "aws_iam_policy" "worker_policy" {
  name        = "worker-policy"
  description = "Worker policy for ECR"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        }
    ]
})
}
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = module.eks.eks_managed_node_groups

  policy_arn = aws_iam_policy.worker_policy.arn
  role       = each.value.iam_role_name
} 


# Creating ecr for the created image
resource "aws_ecr_repository" "ecr" {
  name = var.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"
}

#_----------------------------------------
##############################
# Creating Jenkins instance  #
##############################
#_----------------------------------------
# Creating security group to allow http and ssh
resource "aws_security_group" "sprints_sg" {
  name        = "jenkins_sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.outside_cidr_block]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.outside_cidr_block]
  }


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.outside_cidr_block]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.outside_cidr_block]
  }
  ingress {
    from_port   = 4040
    to_port     = 4040
    protocol    = "tcp"
    cidr_blocks = [local.outside_cidr_block]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = [local.outside_cidr_block]
  }
  tags = {
    Name = "Jenkins_sg"
  }
}



# Getting AMI data
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical 
}


resource "aws_iam_role" "jenkins-role" {
  name = "jenkins_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Creating admin policy for the instance
resource "aws_iam_policy" "jenkins_iam_policy" {
  name = "Jenkins-Policy-Name"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "*",
        "Resource" : "*"
      }
    ]
  })
}


# Attach the IAM policy to the IAM role
resource "aws_iam_policy_attachment" "jenkins_role_policy_attachment" {
  name = "Policy Attachement"
  policy_arn = aws_iam_policy.jenkins_iam_policy.arn
  roles       = [aws_iam_role.jenkins-role.name]
}

resource "aws_iam_instance_profile" "jenkins-profile" {
  name = "jenkins_profile"
  role = aws_iam_role.jenkins-role.name
}


# Creating the public instances with provided information
resource "aws_instance" "jenkins-ec2" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = var.key_name
  associate_public_ip_address = true
  subnet_id = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.sprints_sg.id]
  iam_instance_profile = aws_iam_instance_profile.jenkins-profile.name
  tags = {
    Name = "Jenkins"
  }
  provisioner "local-exec" { # Creating ansible hosts file
    command = "echo '[test]\n${self.public_ip} ansible_user=\"ubuntu\" ansible_ssh_private_key_file=\"./${var.key_name}.pem\"' > hosts"
  }
  provisioner "local-exec" { # Creating ansible vars file
    command = "echo '---\njenkins_user: ${var.jenkins_info[0]}\njenkins_password: ${var.jenkins_info[1]}\njenkins_fullname: ${var.jenkins_info[2]}\njenkins_email: ${var.jenkins_info[2]}' > vars.yml"
  }
}


#################################
# NGINX controller installation #
#################################

# Using helm to install nginx controller 
resource "helm_release" "nginx-ingress-controller" {
  depends_on = [ module.eks ]
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"


  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

}  

###################
# EBS CSI Role    #
###################

module "ebs_csi_eks_role" {
  depends_on = [ module.eks ]
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "ebs_csi"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

###################
# EBS CSI Driver  #
###################

resource "helm_release" "ebs_csi_driver" {
  depends_on = [ module.eks ]
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    type  = "string"
    value = module.ebs_csi_eks_role.iam_role_arn
  }
}

###################
# Storage Classes #
###################
# Creating storage class manifest for the cluster
resource "kubernetes_storage_class_v1" "storageclass_gp2" {
  depends_on = [helm_release.ebs_csi_driver, module.ebs_csi_eks_role]
  metadata {
    name = "gp2-encrypted"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp2"
    encrypted = "true"
  }

} 

#################################
# Output to use after terraform #
#################################

output "update_local_context_command" {
  description = "Command to update local kube context"
  value       = "aws eks update-kubeconfig --name=${var.cluster_name} --region=us-east-1"
}

#############################################
# Environment variables to use with jenkins #
#############################################
data "aws_caller_identity" "current" {} 
data "aws_region" "current" {}

output "ecr_environment_variable" {
  value = "\nECR_URL=${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com\nREPO_NAME=${var.ecr_repo_name}\nCLUSTER_NAME=${var.cluster_name}"
}






















/* 
module "eks-kubeconfig" {
  source  = "hyperbadger/eks-kubeconfig/aws"
  depends_on = [module.eks]
  cluster_name = module.eks.cluster_name
}

resource "local_file" "kubeconfig" {
  content  = module.eks-kubeconfig.kubeconfig
  filename = "kubeconfig_${local.cluster_name}"
} */