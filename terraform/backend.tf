terraform{
    backend "s3" {
      bucket = "terraform-state-demo-v1"
      key = "ec2/terraform.tfstate"
      region = "ap-south-1"
      encrypt= true
    }
}