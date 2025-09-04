pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
    choice(name: 'ACTION', choices: ['apply','destroy'], description: 'Terraform action')
    string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region')
    string(name: 'TF_VAR_key_name', defaultValue: 'your-existing-keypair', description: 'Existing EC2 key pair name')
    string(name: 'TF_VAR_ssh_ingress_cidr', defaultValue: '0.0.0.0/0', description: 'CIDR for SSH (tighten for security)')
    string(name: 'TF_VAR_project_name', defaultValue: 'flask-jenkins-demo', description: 'Project tag')
    string(name: 'ANSIBLE_APP_REPO', defaultValue: 'https://github.com/your-user/your-flask-repo.git', description: 'Flask repo URL')
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
      when { expression { return params.ACTION == 'apply' } }
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials'],
          sshUserPrivateKey(credentialsId: 'ec2-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')
        ]) {
          script {
            def ip = sh(script: "cd terraform && terraform output -raw public_ip", returnStdout: true).trim()
            echo "EC2 Public IP: ${ip}"

            sh """
              export ANSIBLE_HOST_KEY_CHECKING=False
              export ANSIBLE_STDOUT_CALLBACK=yaml

              # Wait for SSH to be ready
              for i in {1..30}; do
                nc -z -w3 ${ip} 22 && echo 'SSH reachable' && break
                echo 'Waiting for SSH...'; sleep 5
              done

              # Install Ansible collections if needed
              ansible-galaxy collection install community.docker || true

              # Deploy using Ansible
              ansible-playbook \
                -i '${ip},' \
                -u '${ANSIBLE_USER}' \
                --private-key '${SSH_KEY}' \
                ansible/site.yml \
                -e app_repo_url='${ANSIBLE_APP_REPO}'
            """
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
