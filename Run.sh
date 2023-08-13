#!/bin/bash
terraform_dir="./Terraform/"  # Adjust to your Terraform directory
ansible_dir="../Ansible"      # Adjust to your Ansible directory

echo "- Please don't change directories names. (Terraform,Ansible)"
echo "- Please make sure to put ssh private key in Ansbile directory."
echo "- Run Terraform init ONLY for the first time."
echo "Select an action:"
echo "1. Build"
echo "2. Destroy"

read -p "Enter the number of your choice: " choice

case $choice in
    1)
        echo "Building with Terraform..."
        cd "$terraform_dir" || exit 1
        terraform apply -auto-approve
        if [ $? -eq 0 ]; then # Checks if the terraform runs succefully
            echo "Infrastructure build successful. Running Ansible script..."
            #sleep 20 # Sleep After creating infrastructure to take the values
            if [ -d "$ansible_dir" ]; then # Check if Ansible directory in exisit
                echo "Ansible files found. Running Ansible script..."
                # Move the created files (hosts and vars to Ansible directory)
                mv -f hosts $ansible_dir/hosts 
                mv -f vars.yml $ansible_dir/vars.yml
                cd "$ansible_dir" || exit 1
                # Install collection of jenkins plugins
                ansible-galaxy collection install community.general
                ansible-playbook -i "./hosts" playbook.yaml
            else
                echo "Ansible files not found in the directory: $ansible_dir"
                exit 1
            fi
        else
            echo "Infrastructure build failed."
            exit 1
        fi
        ;;
    2)
        echo "Destroying with Terraform..."
        cd "$terraform_dir" || exit 1
        terraform destroy -auto-approve
        if [ $? -eq 0 ]; then
            echo "Infrastructure destroy successful."
        else
            echo "Infrastructure destroy failed."
            exit 1
        fi
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac
