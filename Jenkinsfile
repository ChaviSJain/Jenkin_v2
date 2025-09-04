pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
    choice(name: 'ACTION', choices: ['apply','destroy'], description: 'Terraform action')
    string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region')
    string(name: 'TF_VAR_key_name', defaultValue: 'flask-deploy-key', description: 'Existing EC2 key pair name')
    string(name: 'TF_VAR_ssh_ingress_cidr', defaultValue: '0.0.0.0/0', description: 'CIDR for SSH (tighten for security)')
    string(name: 'TF_VAR_project_name', defaultValue: 'flask-jenkins-demo', description: 'Project tag')
    string(name: 'ANSIBLE_APP_REPO', defaultValue: 'https://github.com/ChaviSJain/Test-app.git', description: 'Flask repo URL')
    string(name: 'ANSIBLE_USER', defaultValue: 'ubuntu', description: 'SSH user for the AMI')
  }

  environment {
    TF_IN_AUTOMATION = 'true'
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
        withCredentials([sshUserPrivateKey(credentialsId: 'SSH-PRIVATE-KEY', keyFileVariable: 'SSH_KEY')]) {
          dir('ansible') {
            sh '''
              # Get EC2 IP from Terraform output
              EC2_IP=$(terraform -chdir=../terraform output -raw public_ip)

              echo "[myvm]" > inventory.ini
              echo "$EC2_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> inventory.ini

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
