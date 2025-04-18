terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "ec2_instance" {
  source = "modules/aws/ec2_instance"

  ami           = var.ami
  instance_type = var.instance_type
  instance_name = var.instance_name
}