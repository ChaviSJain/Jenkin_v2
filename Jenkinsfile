pipeline {                     // Start of Jenkins declarative pipeline
  agent any                    // Run this pipeline on any available Jenkins agent/node

  options {
    timestamps()               // Add timestamps to console logs for better debugging
  }

  // Input parameters for the pipeline
  parameters {
    choice(                    // Dropdown choice parameter
      name: 'ACTION',          // Parameter name: ACTION
      choices: ['apply','destroy'], // User can pick 'apply' (create infra) or 'destroy' (delete infra)
      description: 'Terraform action' // Description shown in Jenkins UI
    )
  }

  environment {                // Define global environment variables
    TF_IN_AUTOMATION       = 'true'  // Prevent interactive Terraform prompts
    AWS_REGION             = 'ap-south-1'  // AWS region where infra will be deployed
    TF_VAR_key_name        = 'flask-deploy-key'   // Terraform variable: EC2 key pair
    TF_VAR_ssh_ingress_cidr = '0.0.0.0/0'          // Terraform variable: allow SSH from all IPs
    TF_VAR_project_name    = 'flask-jenkins-demo' // Terraform variable: project tag
    ANSIBLE_APP_REPO       = 'https://github.com/ChaviSJain/Test-app.git' // Flask app repo
    ANSIBLE_USER           = 'ubuntu'             // Default EC2 user for Ubuntu AMI
  }

  stages {                     // Define the ordered pipeline stages

    stage('Checkout') {        // Stage 1: Pull Jenkinsfile and repo code
      steps {
        checkout scm           // Check out source code from configured Git SCM
      }
    }

    stage('Lint & Validate') { // Stage 2: Run validations before infra provisioning
      steps {
      // Inject AWS credentials for Terraform validation
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                      credentialsId: 'aws-credentials']]) {
        sh '''                 # Multi-line shell script block
          echo ">>> Running Terraform validation"
          export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
          export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
          export AWS_DEFAULT_REGION='${AWS_REGION}'
          terraform -chdir=terraform init -backend=false   # Init Terraform (no backend)
          terraform -chdir=terraform validate              # Validate Terraform configs

          echo ">>> Running Ansible syntax check"
          ansible-playbook -i localhost, --syntax-check ansible/site.yml # Validate playbook syntax

          echo ">>> Running ansible-lint (if installed)"
          command -v ansible-lint && ansible-lint ansible/site.yml || echo "ansible-lint not installed"

          echo ">>> Running Python lint (flake8) if app code exists"
          if [ -d flaskapp ]; then                          # If flaskapp folder exists
            command -v flake8 && flake8 flaskapp || echo "flake8 not installed" # Lint Python
          fi
        '''
       }
      }
   }


    stage('Show Tool Versions') { // Stage 3: Print tool versions (debugging)
      steps {
        sh '''
          echo "===== Versions ====="
          terraform -version   # Show Terraform version
          ansible --version    # Show Ansible version
          aws --version        # Show AWS CLI version
        '''
      }
    }

    stage('Terraform Init + Apply/Destroy') { // Stage 4: Provision/destroy infra
      environment {
        TF_CLI_ARGS = "-input=false" // Force Terraform to run non-interactively
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', // Use stored AWS creds
                          credentialsId: 'aws-credentials']]) {
          dir('terraform') {   // Move into terraform/ directory
            script {
              if (params.ACTION == "destroy") { // If destroy action requested
                input message: "⚠️ Confirm you want to DESTROY infrastructure?", ok: "Yes, Destroy" // Ask user to confirm
              }
            }
            sh '''
              export AWS_DEFAULT_REGION='${AWS_REGION}'  # Set AWS region
              export TF_VAR_key_name=${TF_VAR_key_name}  # Export Terraform variables
              export TF_VAR_ssh_ingress_cidr=${TF_VAR_ssh_ingress_cidr}
              export TF_VAR_project_name=${TF_VAR_project_name}

              terraform init -reconfigure -input=false   # Initialize Terraform with backend

              if [ "${ACTION}" = "destroy" ]; then       # If user selected destroy
                terraform destroy -auto-approve          # Destroy infra without prompt
              else
                terraform plan -out=tf.plan              # Create Terraform execution plan
                terraform apply -auto-approve tf.plan    # Apply the plan automatically
              fi
            '''
          }
        }
      }
    }

    stage('Ansible Deploy (only on apply)') { // Stage 5: Configure EC2 with Ansible
      when { expression { params.ACTION == 'apply' } } // Only run if ACTION=apply
      steps {
        withCredentials([sshUserPrivateKey(              // Inject SSH private key
          credentialsId: 'SSH-PRIVATE-KEY',              // ID of stored key in Jenkins
          keyFileVariable: 'SSH_KEY')]) {                // Save key in variable $SSH_KEY
          dir('ansible') {  // Move into ansible/ directory
            sh '''
              EC2_IP=$(terraform -chdir=../terraform output -raw public_ip) # Get EC2 public IP

              echo "[myvm]" > inventory.ini                                  # Create inventory file
              echo "$EC2_IP ansible_user=${ANSIBLE_USER} ansible_ssh_private_key_file=$SSH_KEY" >> inventory.ini

              ansible-playbook -i inventory.ini site.yml                     # Run Ansible playbook
            '''
          }
        }
      }
    }

    stage('Verify Deployment') { // Stage 6: Check if Flask app is working
      when { expression { params.ACTION == 'apply' } } // Only run on apply
      steps {
        sh '''
          EC2_IP=$(terraform -chdir=terraform output -raw public_ip) # Get EC2 public IP
          echo ">>> Checking if Flask app is up..."
          curl -f http://$EC2_IP:5000 || (echo "Flask app not responding!" && exit 1) # Verify app
        '''
      }
    }
  }

  post {                        // Always executed at the end of pipeline
    always {
      archiveArtifacts artifacts: 'terraform/*.tfstate*', // Save Terraform state files
                        allowEmptyArchive: true           // Skip if no files
      cleanWs()   // Clean Jenkins workspace after job to free space
    }
  }
}
