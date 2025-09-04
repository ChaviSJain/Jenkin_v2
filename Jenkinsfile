pipeline {
    agent any

    options {
        timestamps()
    }

    parameters {
        choice(name: 'ACTION', choices: ['apply','destroy'], description: 'Terraform action')
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region')
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
                  echo "===================="
                '''
            }
        }

        stage('Terraform Apply/Destroy') {
            environment {
                TF_CLI_ARGS = "-input=false"
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-access-key-id'
                ]]) {
                    dir('terraform') {
                        sh '''
                          export AWS_DEFAULT_REGION="${AWS_REGION}"
                          terraform init
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
                    sshUserPrivateKey(credentialsId: 'SSH-PRIVATE-KEY', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')
                ]) {
                    script {
                        def ip = sh(script: "cd terraform && terraform output -raw public_ip", returnStdout: true).trim()
                        echo "EC2 Public IP: ${ip}"

                        sh """
                          export ANSIBLE_HOST_KEY_CHECKING=False
                          echo "Waiting for SSH on ${ip}..."
                          for i in {1..30}; do
                            nc -z -w3 ${ip} 22 && echo 'SSH ready' && break
                            echo 'Still waiting for SSH...'; sleep 5
                          done

                          ansible-playbook \
                            -i '${ip},' \
                            -u '${SSH_USER}' \
                            --private-key '${SSH_KEY}' \
                            ansible/site.yml
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
