resource "aws_security_group" "resource-provisioner-api-sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow_http" {
  security_group_id = aws_security_group.resource-provisioner-api-sg.id
  type = "ingress"
  from_port = 5000
  to_port = 5000
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_secretsmanager_secret" "resource-provisioner-api-ec2-private-key" {
  name = "resource-provisioner-api-ec2-private-key-${random_id.unique_suffix.hex}"
  description = "The private key for SSH access"
}

resource "random_id" "unique_suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret_version" "resource-provisioner-api-ec2-private-key" {
  secret_id = aws_secretsmanager_secret.resource-provisioner-api-ec2-private-key.id
  secret_string = var.resource_provisioner_api_private_key
}