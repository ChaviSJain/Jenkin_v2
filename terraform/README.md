Terraform configuration for provisioning an EC2 instance on AWS, with remote state management via S3.


Execution Flow Overview

Terraform Initialization (terraform init)
  Reads backend.tf to configure remote state in S3.
  Downloads AWS provider plugin.

Terraform Planning (terraform plan)
  Loads variables from variables.tf.
  Parses main.tf to understand resources to create.
  Prepares execution plan.

Terraform Apply (terraform apply)
  Provisions EC2 instance using values from variables.tf.
  Stores state remotely in the S3 bucket.
  Outputs instance ID and public IP via outputs.tf.

  