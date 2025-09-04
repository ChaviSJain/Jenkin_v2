pipeline {
  agent any

  options {
    timestamps()  // add timestamps to logs
  }

  // Only keep ACTION as parameter (apply/destroy)
  parameters {
    choice(name: 'ACTION', choices: ['apply','destroy'], description: 'Terraform action')
  }

  environment {
    // Global env vars (constants)
    TF_IN_AUTOMATION       = 'true'
    AWS_REGION             = 'ap-south-1'
    TF_VAR_key_name        = 'flask-deploy-key'   // existing EC2 key pair
    TF_VAR_ssh_ingress_cidr= '0.0.0.0/0'          // security: tighten in prod
    TF_VAR_project_name    = 'flask-jenkins-demo'
    ANSIBLE_APP_REPO       = 'https://github.com/ChaviSJain/Test-app.git'
    ANSIBLE_USER           = 'ubuntu'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
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
        TF_CLI_ARGS = "-input=false"
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-credentials']]) {
          dir('terraform') {
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
  when { expression { params.ACTION == 'apply' } }
  steps {
    withCredentials([
      sshUserPrivateKey(credentialsId: 'SSH-PRIVATE-KEY', keyFileVariable: 'SSH_KEY'),
      [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']
    ]) {
      dir('ansible') {
        sh '''#!/bin/bash
          # Get EC2 IP from Terraform output
          EC2_IP=$(terraform -chdir=../terraform output -raw public_ip)

          echo "[myvm]" > inventory.ini
          echo "$EC2_IP ansible_user=${ANSIBLE_USER} ansible_ssh_private_key_file=$SSH_KEY" >> inventory.ini

          # Wait for SSH
          until nc -zv $EC2_IP 22; do
            echo "Waiting for SSH..."
            sleep 5
          done

          ansible-playbook -i inventory.ini site.yml
        '''
      }
    }
  }
}

  }

  post {
    always {
      archiveArtifacts artifacts: 'terraform/*.tfstate*', allowEmptyArchive: true
    }
  }
}
