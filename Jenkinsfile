pipeline {                     
  agent any                    

  options {
    timestamps()               
  }

  parameters {
    choice(                    
      name: 'ACTION',          
      choices: ['apply','destroy'], 
      description: 'Terraform action' 
    )
  }

  environment {                
    TF_IN_AUTOMATION        = 'true'  
    AWS_REGION              = 'ap-south-1'  
    TF_VAR_key_name         = 'flask-deploy-key'   
    TF_VAR_ssh_ingress_cidr = '0.0.0.0/0'          
    TF_VAR_project_name     = 'flask-jenkins-demo' 
    ANSIBLE_APP_REPO        = 'https://github.com/ChaviSJain/Test-app.git' 
    ANSIBLE_USER            = 'ubuntu'             
  }

  stages {                     

    stage('Checkout') {        
      steps {
        checkout scm
      }
    }

    stage('Lint & Validate') { 
      steps {
        sh """#!/bin/bash
          echo ">>> Running Terraform validation"
          export AWS_ACCESS_KEY_ID=\$AWS_ACCESS_KEY_ID
          export AWS_SECRET_ACCESS_KEY=\$AWS_SECRET_ACCESS_KEY
          export AWS_DEFAULT_REGION=\$AWS_REGION

          terraform -chdir=terraform init -backend=false | tee terraform-init.log
          terraform -chdir=terraform validate | tee terraform-validate.log

          echo ">>> Running Ansible syntax check"
          ansible-playbook -i localhost, --syntax-check ansible/site.yml

          echo ">>> Running ansible-lint (if installed)"
          command -v ansible-lint && ansible-lint ansible/site.yml || echo "ansible-lint not installed"

          echo ">>> Running Python lint (flake8) if app code exists"
          if [ -d flaskapp ]; then
            command -v flake8 && flake8 flaskapp || echo "flake8 not installed"
          fi
        """
      }
    }

    stage('Show Tool Versions') { 
      steps {
        sh """#!/bin/bash
          echo "===== Versions ====="
          terraform -version
          ansible --version
          aws --version
        """
      }
    }

    stage('Terraform Init + Apply/Destroy') {
      environment {
        TF_CLI_ARGS = "-input=false"
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
          dir('terraform') {
            script {
              if (params.ACTION == "destroy") {
                input message: "⚠️ Confirm you want to DESTROY infrastructure?", ok: "Yes, Destroy"
              }

              sh """#!/bin/bash
                export AWS_DEFAULT_REGION=\$AWS_REGION
                export TF_VAR_key_name=\$TF_VAR_key_name
                export TF_VAR_ssh_ingress_cidr=\$TF_VAR_ssh_ingress_cidr
                export TF_VAR_project_name=\$TF_VAR_project_name

                terraform init -reconfigure -input=false

                if [ "\$ACTION" = "destroy" ]; then
                  terraform destroy -auto-approve
                else
                  terraform plan -out=tf.plan
                  terraform apply -auto-approve tf.plan
                fi
              """
            }
          }
        }
      }
    }

    stage('Ansible Deploy (only on apply)') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'SSH-PRIVATE-KEY',
          keyFileVariable: 'SSH_KEY')]) {
          dir('ansible') {
            sh """#!/bin/bash
              echo ">>> Waiting for SSH to become ready..."
              until nc -zv \$EC2_IP 22; do
                sleep 5
                echo "Waiting for SSH..."
              done
              echo ">>> SSH is ready!"

              echo "[myvm]" > inventory.ini
              echo "\$EC2_IP ansible_user=\$ANSIBLE_USER ansible_ssh_private_key_file=\$SSH_KEY" >> inventory.ini

              ansible-playbook -i inventory.ini site.yml
            """
          }
        }
      }
    }

    stage('Verify Deployment') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        sh """#!/bin/bash
          echo ">>> Waiting 10 seconds for Flask app to start..."
          sleep 10
          echo ">>> Checking if Flask app is up at \$EC2_IP:5000 ..."
          curl -f http://\$EC2_IP:5000 || (echo "Flask app not responding!" && exit 1)
        """
      }
    }
  }

  post {                        
    always {
      archiveArtifacts artifacts: 'terraform/*.tfstate*', 
                        allowEmptyArchive: true           
      cleanWs()   
    }
  }
}
