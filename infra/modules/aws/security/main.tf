resource "aws_security_group" "cloud_ops_manager_api_sg" {
  name        = "cloud-ops-manager-api-sg"
  description = "Security group for CloudOps Manager API"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP access from API Gateway"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH access from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-ops-manager-api-sg"
  }
}