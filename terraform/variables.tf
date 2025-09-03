variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-south-1"
}

variable "key_name" {
  type        = string
  description = "flask-deploy-key"
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "CIDR allowed for SSH (22)"
  default     = "0.0.0.0/0" # tighten to your IP/cidr
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  type        = string
  default     = "flask-jenkins-demo"
}
