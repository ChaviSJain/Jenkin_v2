pipeline {
  agent any  // Run this pipeline on any available Jenkins agent/node

  options {
    timestamps()  // timestamps to each log line in the Jenkins console for easier debugging
  }

  // Define parameters that users can select when triggering the pipeline
  parameters {
    choice(
      name: 'ACTION',                   // Name of the parameter
      choices: ['apply','destroy'],     // Allowed values: "apply" for creating resources, "destroy" for deleting resources
      description: 'Terraform action'   // Help text shown in Jenkins UI
    )
  }

  // Define environment variables available globally across all stages
  environment {
    TF_IN_AUTOMATION       = 'true'                     // Tell Terraform it is running in automated mode (non-interactive)
    AWS_REGION             = 'ap-south-1'               
    TF_VAR_key_name        = 'flask-deploy-key'         // Terraform variable for existing EC2 key pair
    TF_VAR_ssh_ingress_cidr= '0.0.0.0/0'               // Terraform variable for security group (allow SSH from anywhere; should tighten in production)
    TF_VAR_project_name    = 'flask-jenkins-demo'       // Terraform variable for project name, used in resource naming
    ANSIBLE_APP_REPO       = 'https://github.com/ChaviSJain/Test-app.git' // Git repo of the application to deploy via Ansible
    ANSIBLE_USER           = 'ubuntu'                   // User to connect via SSH to EC2
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm  // Pull the source code from the repository associated with this Jenkins job
      }
    }

    stage('Show Tool Versions') {
      steps {
        sh '''
          echo "===== Versions ====="
          terraform -version   
          ansible --version    
          aws --version        
        '''
      }
    }

    stage('Terraform Init + Apply/Destroy') {
      environment {
        TF_CLI_ARGS = "-input=false"  // Disable interactive prompts during Terraform operations
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-credentials']]) {  // Use stored AWS credentials in Jenkins
          dir('terraform') {  // Change working directory to "terraform",# Ensure AWS CLI and Terraform use the correct region
            sh '''
              export AWS_DEFAULT_REGION='${AWS_REGION}'   

              echo ">>> Running terraform init with S3 backend"
              terraform init -reconfigure -input=false     

              if [ "${ACTION}" = "destroy" ]; then         
                terraform destroy -auto-approve           
              else
                terraform plan -out=tf.plan               
                terraform apply -auto-approve tf.plan     
              fi
            '''
          }
        }
      }
    }

    stage('Ansible Deploy (only on apply)') {
      when { expression { params.ACTION == 'apply' } } // Only run this stage if ACTION parameter is "apply"
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'SSH-PRIVATE-KEY', keyFileVariable: 'SSH_KEY'), // SSH key for Ansible to connect to EC2
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials'] // AWS credentials if needed
        ]) {
          dir('ansible') {  // Change working directory to "ansible"
            sh '''#!/bin/bash
              # Get EC2 IP from Terraform output
              EC2_IP=$(terraform -chdir=../terraform output -raw public_ip)

              # Create dynamic Ansible inventory
              echo "[myvm]" > inventory.ini
              echo "$EC2_IP ansible_user=${ANSIBLE_USER} ansible_ssh_private_key_file=$SSH_KEY" >> inventory.ini

              # Wait until SSH port 22 is open on EC2
              until nc -zv $EC2_IP 22; do
                echo "Waiting for SSH..."
                sleep 5
              done

              # Run Ansible playbook using the generated inventory
              ansible-playbook -i inventory.ini site.yml
            '''
          }
        }
      }
    }
 
    stage('Validate EC2 Instance') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                      credentialsId: 'aws-credentials']]) {
          dir('terraform') {
            sh '''
              export AWS_DEFAULT_REGION=${AWS_REGION}
              EC2_IP=$(terraform output -raw public_ip)

              echo "Checking if EC2 instance $EC2_IP is up..."
              if nc -zv $EC2_IP 22; then
                echo "✅ EC2 is reachable via SSH"
              else
                echo "❌ EC2 is not reachable!"
              exit 1
              fi
           '''
          }
        }
      }
   }

    stage('Validate Flask App') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                      credentialsId: 'aws-credentials']]) {
        dir('terraform') {
          sh '''
            EC2_IP=$(terraform output -raw public_ip)

            echo "Checking if Flask app is running on $EC2_IP:5000..."
            STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$EC2_IP:5000/)

            if [ "$STATUS_CODE" -eq 200 ]; then
              echo "✅ Flask app is running successfully!"
            else
              echo "❌ Flask app is not responding! Status code: $STATUS_CODE"
            exit 1
            fi
          '''
        }
      }
    }


  } // end stages

  post {
    always {
      archiveArtifacts artifacts: 'terraform/*.tfstate*', allowEmptyArchive: true  // Save Terraform state files as Jenkins artifacts, even if no files found
    }
  }
}
}