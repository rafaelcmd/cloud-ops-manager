# ---------------------------------------------------------------------------------
# Provider Configuration
# ---------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ------------------------------------------------------------------------------
# Terraform Cloud Configuration
# ------------------------------------------------------------------------------
terraform {
  cloud {

    organization = "cloudops-manager-org"

    workspaces {
      name = "cloudops-manager-image-builder"
    }
  }
}

# ------------------------------------------------------------------------------
# VPC, Subnet, Internet Gateway, Route Table, and Security Group
# ------------------------------------------------------------------------------
resource "aws_vpc" "image_builder_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "image-builder-vpc"
  }
}

resource "aws_subnet" "image_builder_subnet" {
  vpc_id                  = aws_vpc.image_builder_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "image-builder-subnet"
  }
}

resource "aws_internet_gateway" "image_builder_igw" {
  vpc_id = aws_vpc.image_builder_vpc.id

  tags = {
    Name = "image-builder-igw"
  }
}

resource "aws_route_table" "image_builder_rt" {
  vpc_id = aws_vpc.image_builder_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.image_builder_igw.id
  }

  tags = {
    Name = "image-builder-rt"
  }
}

resource "aws_route_table_association" "image_builder_rta" {
  subnet_id      = aws_subnet.image_builder_subnet.id
  route_table_id = aws_route_table.image_builder_rt.id
}

resource "aws_security_group" "image_builder_sg" {
  name        = "image-builder-sg"
  description = "Allow SSH, HTTP, HTTPS"
  vpc_id      = aws_vpc.image_builder_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "image-builder-sg"
  }
}

# ------------------------------------------------------------------------------
# IAM Role + Instance Profile for Image Builder
# ------------------------------------------------------------------------------
resource "aws_iam_role" "image_builder_role" {
  name = "cloud-ops-image-builder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "imagebuilder.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "image_builder_policy" {
  role       = aws_iam_role.image_builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_instance_profile" "image_builder_profile" {
  name = "cloud-ops-imagebuilder-profile"
  role = aws_iam_role.image_builder_role.name
}

# ------------------------------------------------------------------------------
# Image Recipe
# ------------------------------------------------------------------------------
resource "aws_imagebuilder_image_recipe" "image_builder_recipe" {
  name         = "image-builder-recipe"
  version      = "1.0.0"
  parent_image = "ami-08b5b3a93ed654d19"

  block_device_mapping {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  component {
    component_arn = "arn:aws:imagebuilder:us-east-1:aws:component/update-linux/1.0.2/1"
  }

  description = "CloudOps Manager Base Image"
}

# ------------------------------------------------------------------------------
# Infrastructure Configuration
# ------------------------------------------------------------------------------
resource "aws_imagebuilder_infrastructure_configuration" "image_builder_infra" {
  name                          = "cloud-ops-infra-config"
  instance_profile_name         = aws_iam_instance_profile.image_builder_profile.name
  subnet_id                     = aws_subnet.image_builder_subnet.id
  security_group_ids            = [aws_security_group.image_builder_sg.id]
  terminate_instance_on_failure = true

  tags = {
    Name = "cloud-ops-infra"
  }
}

# ------------------------------------------------------------------------------
# Image Pipeline
# ------------------------------------------------------------------------------
resource "aws_imagebuilder_image_pipeline" "cloud_ops_pipeline" {
  name                             = "cloud-ops-pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.image_builder_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.image_builder_infra.arn

  tags = {
    Name = "cloud-ops-pipeline"
  }
}
