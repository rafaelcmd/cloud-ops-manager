resource "aws_instance" "cloud_ops_manager_api_ec2" {
  ami                         = "ami-08b5b3a93ed654d19"
  instance_type               = "t2.micro"
  subnet_id                   = var.cloud_ops_manager_public_subnet_id
  vpc_security_group_ids      = [var.cloud_ops_manager_api_security_group_id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.cloud_ops_manager_api_ec2_profile.name

  tags = {
    Name = "cloud-ops-manager-api"
  }
}

resource "aws_instance" "cloud_ops_manager_consumer_ec2" {
  ami                    = "ami-08b5b3a93ed654d19"
  instance_type          = "t2.micro"
  subnet_id              = var.cloud_ops_manager_private_subnet_id
  vpc_security_group_ids = [var.cloud_ops_manager_consumer_security_group_id]

  iam_instance_profile = aws_iam_instance_profile.cloud_ops_manager_api_ec2_profile.name

  tags = {
    Name = "cloud-ops-manager-consumer"
  }
}

resource "aws_iam_role" "cloud_ops_manager_api_ec2_role" {
  name = "cloud-ops-manager-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "cloud_ops_manager_consumer_ec2_role" {
  name = "cloud-ops-manager-consumer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cloud_ops_manager_api_ec2_profile" {
  name = "cloud-ops-manager-api-profile"
  role = aws_iam_role.cloud_ops_manager_api_ec2_role.name
}

resource "aws_iam_instance_profile" "cloud_ops_manager_consumer_ec2_profile" {
  name = "cloud-ops-manager-consumer-profile"
  role = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name
}

resource "aws_iam_role_policy" "cloud_ops_manager_api_ec2_instance_connect" {
  name = "AllowEC2InstanceConnect"
  role = aws_iam_role.cloud_ops_manager_api_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = [
          aws_instance.cloud_ops_manager_api_ec2.arn,
          aws_instance.cloud_ops_manager_consumer_ec2.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloud_ops_manager_consumer_ec2_instance_connect" {
  name = "AllowEC2InstanceConnect"
  role = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = [
          aws_instance.cloud_ops_manager_api_ec2.arn,
          aws_instance.cloud_ops_manager_consumer_ec2.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloud_ops_manager_api_sqs_access" {
  name = "AllowSQSSendMessage"
  role = aws_iam_role.cloud_ops_manager_api_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
        ]
        Resource = var.provisioner_consumer_sqs_queue_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloud_ops_manager_consumer_sqs_access" {
  name = "AllowSQSReceiveMessage"
  role = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.provisioner_consumer_sqs_queue_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloud_ops_manager_api_ssm_access" {
  name = "AllowSSMGetParameters"
  role = aws_iam_role.cloud_ops_manager_api_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = var.provisioner_consumer_sqs_queue_parameter_arn
      }
    ]
  })
}