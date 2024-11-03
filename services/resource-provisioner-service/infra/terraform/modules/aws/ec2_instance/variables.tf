variable "ami" {
    description = "The AMI to use for the EC2 instance"
    type = string
}

variable "instance_type" {
    description = "The type of EC2 instance to launch"
    default     = "t2.micro"
    type = string
}

variable "instance_name" {
    description = "The name of the EC2 instance"
    type = string
}

variable "subnet_availability_zone" {
    description = "The availability zone to deploy the EC2 instance into"
    default = "us-east-1a"
    type = string
}