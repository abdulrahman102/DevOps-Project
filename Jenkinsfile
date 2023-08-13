pipeline {
     agent any

    stages {
        stage('Checking ENVIRONMENT Variables') {
            steps {
                sh '''#!/bin/bash
                    if [ -n "$REPO_NAME" ];then
                        echo "REPO_NAME is defined"
                    else
                        echo "REPO_NAME is not defined"
                        exit 1
                    fi
                    if [ -n "$ECR_URL" ];then
                        echo "ECR_URL is defined"
                    else
                        echo "ECR_URL is not defined"
                        exit 1
                    fi
                '''
            }
        }
        stage('build new Docker images') {
            steps {
                sh 'docker build -t $REPO_NAME MySQL-and-Python/FlaskApp/.'
                sh 'docker tag $REPO_NAME:latest $ECR_URL/$REPO_NAME:${BUILD_NUMBER}'
            }
        }

        stage('Push image to ECR') {
            steps {
                sh 'aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL'
                sh 'docker push $ECR_URL/$REPO_NAME:${BUILD_NUMBER}'
            }
        }
        
        stage('deploy it to kubernetes') {  
            steps {
                script{
                    def REPO_NAME_SED = env.REPO_NAME.replace("/" , "\\\\/")
                    sh "sed -i \"s/image:.*/image: ${ECR_URL}\\\\/${REPO_NAME_SED}:${BUILD_NUMBER}/g\" K8s/App_deployment.yaml"
                    // we changed the format of environment variables here as the "" double qutoin is used
                }
                sh 'aws eks update-kubeconfig --name $CLUSTER_NAME'
                sh 'cd K8s'
                sh 'kubectl apply -f App_configmap.yaml -f secrets.yaml -f db-sql-configmap.yaml -f mysql_statefulset.yaml -f App_deployment.yaml -f ingree_manifest.yaml'

            }
        }  

        stage('Delete created image') {
            steps {
                sh 'docker rmi $ECR_URL/$REPO_NAME:${BUILD_NUMBER}'
                sh 'kubectl get svc nginx-ingress-controller'
            }
        } 
    }

}