<a name="readme-top"></a>


<div align="center">
  <a href="https://github.com/abdulrahman102/Complete-DevOps-Project">
    <img src="https://github.com/abdulrahman102/Complete-DevOps-Project/blob/master/Screenshots/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h1 align="center">DOCUMENTATION</h1>

  <p align="center">
    Deployment of FlaskApp into a Kubernetes cluster 
    <br />
    <a href="https://github.com/abdulrahman102/Complete-DevOps-Project/tree/master/Terraform">Infrastructure files</a>
    ·
    <a href="https://github.com/abdulrahman102/Complete-DevOps-Project/tree/master/Ansible">Configuration files</a>    
    .
    <a href="https://github.com/abdulrahman102/Complete-DevOps-Project/tree/master/K8s">Kubernetes files</a>
    ·
    <a href="https://github.com/abdulrahman102/Complete-DevOps-Project/tree/master/MySQL-and-Python">App & DOCKER files</a>
  </p>
</div>


<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#terraform">TERRAFORM</a></li>
    <li><a href="#ansible">Ansible</a></li>
    <li><a href="#kubernetes">KUBERNETES FILES</a></li>
    <li><a href="#ansible">JENKINS FILE</a></li>
    <li><a href="#docker">DOCKER FILES AND DOCKER-COMPOSE FILES</a></li>
    <li><a href="#bash">BASH SCRIPT</a></li>
  </ol>
</details>


<!-- GETTING STARTED -->
# INFRASTRUCTURE FILES

This a full documentation for the infrastructure provisioning and configuration.


## 1) TERRAFORM
<a name="terraform"></a>


_The used providers are:_
- [AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [KUBERNETES PROVIDER](https://registry.terraform.io/providers/hashicorp/kubernetes/latest)
- [HELM PROVIDER](https://registry.terraform.io/providers/hashicorp/helm/latest)

_The used modules are:_
- [VPC MODULE](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [EKS MODULE](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [EBS CSI EKS ROLE](https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest/submodules/iam-role-for-service-accounts-eks)  

-----
### VPC & EKS 
The terraform file starts with creating a vpc with a default availability zones depends on a given number of public and private subnets by the vpc module and give them tags for cluster to identify the infrastructure.

After that, the EKS module starts to create the cluster with the given variables and an EKS managed group nodes, to give it the responsibility of configuring the nodes with the cluster and install needed tools on them.

And give the worker nodes open inbound rules to allow communication between each others. 

### JENKINS EC2 Instance
Jenkins will be hosted on an EC2 instance and will be Configured using Ansible, but for the EC2 instance itself it will be an ubuntu instance with a security group allowing traffics mainly from ssh and port 8080 (used by jenkins app) and port 4040 (used by ngrok).

The created instance will have an administration IAM role for the ECR and EKS communication.
> **NOTE**: For Jenkins you can provide credentials by too many ways, but I found it the most secure and automated way.

### ECR 
The created ECR used to push any changes in the code and making it easy for kubernetes to deploy it to the cluster.

For EKS worker nodes, we will provide additional IAM role for accessing ECR.

### INGRESS CONTROLLER
For Ingress controller, I have chosen helm chart and set the service type to load balancer to easily access the classic load balancer created by default.

### STORAGE CLASS MANIFEST
For the dynamically allocation storage in the cluster, we need to provide an ebs driver, role and storage class to easily integrate with pvc.
I have chosen the helm chart of ebs driver and module for the rules.


### OUTPUTS
The output of the [main.tf]() file will be 
- Command to connect to the cluster.
- ENVIRONMENT variable needed in Jenkins app. 
- hosts and vars.yml files inside terraform directory
> **NOTE**: You must add these files manually if you didn't run it from script. 

-----
<a name="ansible"></a>

## 2) Ansible
_Ansible is used to configure the Jenkins instance_

Ansible 4 main files:
- playbook.yaml: contains the commands that will run on the remote host.
- hosts: contains the host IP and the ssh key
- vars.yml: Contains the variables values
- ansible.cfg: contains the options to make the process more automated

The playbook has the logic of installing some important tool on the machine to run jenkins immediately without the needing of manual configuration.
the steps are :
1. Installing Java (important to install jenkins)
2. Installing jenkins (The main tool)
3. Installing AWS-CLI-2 (To configure with AWS)
4. Installing kubectl (To interact with the cluster)
5. Installing Docker (For building, pulling and pushing images)
6. Add Jenkins User (By sending API POST request with the data)
7. Add most used plugins to jenkins (Most important ones are git, github and envinject) 
8. Skip the initial setup page (By change the environment variable inside java)
9. Reloading Jenkins
10. Displaying the url of the jenkins file 

> **NOTE**: You should add the url inside the app manually (preferred to be a real domain name) 

![](https://github.com/abdulrahman102/Complete-DevOps-Project/blob/master/Screenshots/jenkinsurl1.png)
![](https://github.com/abdulrahman102/Complete-DevOps-Project/blob/master/Screenshots/jenkinsurl2.png)

**Use the env injection as illustrated in [README.md]().**

-----
<a name="kubernetes"></a>

## 3) KUBERNETES FILES
_YAML files that will be deployed with every build_
K8s Directory contains 6 yaml files:

**1- APP CONFIG MAP**
- DB connection data.

**2- DB SQL CONFIGMAP**
- volume containing the sql files that will run at the start of the pod.

**3- SECRETS**
- The password of the DB

**4- APP DEPLOYMENT**
- The deployment with the number of replicas , service and pvc inside one yaml manifestation.

**5- MYSQL DB STATEFULSET**
- with service and VolumeClaim template

**6- INGRESS MANIFEST**
- for the routing rules of the ingress

> **NOTE**: You should configure number of replicas and database connection credentials manually.

----
<a name="jenkins"></a>

## 4) JENKINS FILE
_Is used to define the build process for the pipeline_

1. Check if the user have entered the environment variables.
2. Building docker image from the files in the repo.
3. Push it to the ecr with the build number tag.
4. add it to kubernetes manifest. 
5. Delete the used image locally.
6. View the site url in the console.

----
## 5) DOCKER FILES AND DOCKER-COMPOSE FILES
<a name="docker"></a>
_INSIDE [MySQL-and-Python]() directory. there is a docker compose file that will run fully function app on localhost:5002_

The docker files are used to pull the image of python and install the requirements of the app and start it while starting the db and configure it.
> **NOTE**: The used python image is deprecated as the application itself is old.

------
<a name="bash"></a>

## 6) BASH SCRIPT
_RUN.sh Script is used to run Terraform and Ansible file automatically and check for errors_
![](https://github.com/abdulrahman102/Complete-DevOps-Project/blob/master/Screenshots/scriptbash.png)


