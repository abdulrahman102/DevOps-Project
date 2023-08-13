variable "vpc_name" {
    type = string
    description = "Name of the vpc"
}

variable "cluster_name" {
    type = string
    description = "Name of the cluster"
  
}

variable "ecr_repo_name" {
    type = string
    description = "Name of the ecr repo"
  
}

variable "vpc_cidr_block" {
    type = string
    description = "Cidr block of all IP inside vpc"
}

variable "public_subnet_ips" {
    type = list(string)
    description = "List of all public subnet ip range"
}

variable "private_subnet_ips" {
    type = list(string)
    description = "List of all private subnet ip range"
}

variable "key_name" {
    type = string
    description = "Name of ssh key used to connect to ec2 (must be created on aws)"
  
}

variable "jenkins_info" {
    type = list(string)
    description = "Information of jenkins user in a list [user,passwor,fullname,email]"
}

