resource "aws_security_group" "cloud_ops_manager_api_sg" {
  name        = "cloud-ops-manager-api-sg"
  description = "Security group for CloudOps Manager API"
  vpc_id      = var.cloud_ops_manager_vpc_id

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

resource "aws_security_group" "cloud_ops_manager_consumer_sg" {
  name        = "cloud-ops-manager-consumer-sg"
  description = "Security group for CloudOps Manager Consumer"
  vpc_id      = var.cloud_ops_manager_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-ops-manager-consumer-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow PostgreSQL access from Provisioner Cosumer"
  vpc_id      = var.cloud_ops_manager_vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "cloud_ops_manager_ecs_task_sg" {
  name        = "cloud-ops-manager-api-ecs-sg"
  description = "Security group for CloudOps Manager API ECS tasks"
  vpc_id      = var.cloud_ops_manager_vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "cloud_ops_manager_ecs_alb_sg" {
  name        = "cloud-ops-manager-ecs-alb-sg"
  description = "Security group for CloudOps Manager ECS ALB"
  vpc_id      = var.cloud_ops_manager_vpc_id

  ingress {
    description = "Allow HTTP access from API Gateway"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow_alb_to_ecs" {
  type                     = "ingress"
  from_port                = 5000
  to_port                  = 5000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cloud_ops_manager_ecs_task_sg.id
  source_security_group_id = aws_security_group.cloud_ops_manager_ecs_alb_sg.id
}