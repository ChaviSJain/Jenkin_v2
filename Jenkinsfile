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
                  terraform -version || echo "Terraform not installed"
                  ansible --version || echo "Ansible not installed"
                  aws --version || echo "AWS CLI not installed"
                  echo "===================="
                '''
            }
        }

        stage('Terraform Action') {
            steps {
                script {
                    dir('terraform') {
                        if (params.ACTION == "destroy") {
                            sh 'echo "Running: terraform destroy (stub)"'
                            // replace with: terraform destroy -auto-approve
                        } else {
                            sh 'echo "Running: terraform init/plan/apply (stub)"'
                            // replace with:
                            // terraform init
                            // terraform plan -out=tf.plan
                            // terraform apply -auto-approve tf.plan
                        }
                    }
                }
            }
        }

        stage('Ansible Deploy (Stub)') {
            when { expression { return params.ACTION == 'apply' } }
            steps {
                sh '''
                  echo "Would run ansible-playbook here..."
                  echo "Simulating Ansible deployment"
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. (You can add archiving later)"
        }
    }
}
