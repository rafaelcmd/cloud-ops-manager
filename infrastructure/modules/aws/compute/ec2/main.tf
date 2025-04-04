resource "aws_iam_role" "ec2_role" {
  name = "resource-provisioner-api-role"

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

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "resource-provisioner-api-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy" "ec2_instance_connect" {
  name = "AllowEC2InstanceConnect"
  role = aws_iam_role.ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "sqs_access" {
  name = "AllowSQSSendMessage"
  role = aws_iam_role.ec2_role.name

  policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
      {
          Effect = "Allow"
          Action = [
          "sqs:SendMessage",
          ]
          Resource = var.sqs_queue_arn
      }
      ]
  })
}

resource "aws_iam_role_policy" "ssm_access" {
  name = "AllowSSMGetParameters"
  role = aws_iam_role.ec2_role.name

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = [
            "ssm:GetParameter"
            ]
            Resource = "*"
        }
        ]
    })
}

resource "aws_instance" "resource-provisioner-api" {
  ami                         = "ami-08b5b3a93ed654d19"
  instance_type               = "t2.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "resource-provisioner-api"
  }
}
