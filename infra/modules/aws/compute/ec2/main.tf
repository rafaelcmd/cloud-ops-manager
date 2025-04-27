# ------------------------------------------------------------------------------
# API EC2 Instance
# ------------------------------------------------------------------------------
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

resource "aws_iam_instance_profile" "cloud_ops_manager_api_ec2_profile" {
  name = "cloud-ops-manager-api-profile"
  role = aws_iam_role.cloud_ops_manager_api_ec2_role.name
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

resource "aws_iam_role_policy" "cloud_ops_manager_api_ssm_access" {
  name = "AllowSSMGetParameters"
  role = aws_iam_role.cloud_ops_manager_api_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ]
        Resource = var.provisioner_consumer_sqs_queue_parameter_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_api_ssm_managed_core_attach" {
  role       = aws_iam_role.cloud_ops_manager_api_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_api_cw_agent_attach" {
  role       = aws_iam_role.cloud_ops_manager_api_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_cloudwatch_log_group" "cloud_ops_manager_api_logs" {
  name              = "/aws/ec2/cloud-ops-manager-api"
  retention_in_days = 7

  tags = {
    Name = "cloud-ops-manager-api-logs"
  }
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_api_xray_attach" {
  role       = aws_iam_role.cloud_ops_manager_api_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_ssm_association" "cloud_ops_manager_api_install_cw_agent" {
  name = "AmazonCloudWatch-ManageAgent-API"

  targets {
    key    = "tag:Name"
    values = ["cloud-ops-manager-api"]
  }

  parameters = {
    action                            = "configure"
    mode                              = "ec2"
    optionalConfigurationLocation     = "/CloudOpsManager/CloudWatchAgentConfig-API"
    optionalConfigurationLocationType = "ssm"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cloud_ops_manager_api_ssm_managed_core_attach
  ]
}

resource "aws_ssm_association" "cloud_ops_manager_api_install_xray" {
  name = "AWS-ConfigureAWSPackage"

  targets {
    key    = "tag:Name"
    values = ["cloud-ops-manager-api"]
  }

  parameters = {
    action = "Install"
    name   = "AwsXRayDaemon"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cloud_ops_manager_api_ssm_managed_core_attach
  ]
}

# ------------------------------------------------------------------------------
# Consumer EC2 Instance
# ------------------------------------------------------------------------------
resource "aws_instance" "cloud_ops_manager_consumer_ec2" {
  ami                    = "ami-08b5b3a93ed654d19"
  instance_type          = "t2.micro"
  subnet_id              = var.cloud_ops_manager_private_subnet_id
  vpc_security_group_ids = [var.cloud_ops_manager_consumer_security_group_id]

  iam_instance_profile = aws_iam_instance_profile.cloud_ops_manager_consumer_ec2_profile.name

  tags = {
    Name = "cloud-ops-manager-consumer"
  }
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

resource "aws_iam_instance_profile" "cloud_ops_manager_consumer_ec2_profile" {
  name = "cloud-ops-manager-consumer-profile"
  role = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name
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

resource "aws_iam_role_policy" "cloud_ops_manager_consumer_ssm_access" {
  name = "AllowSSMGetParameters"
  role = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ]
        Resource = var.provisioner_consumer_sqs_queue_parameter_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloud_ops_manager_consumer_s3_access" {
  name = "AllowS3ListBucket"
  role = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.cloud_ops_manager_consumer_deploy_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_consumer_ssm_managed_core_attach" {
  role       = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_consumer_cw_agent_attach" {
  role       = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_cloudwatch_log_group" "cloud_ops_manager_consumer_logs" {
  name              = "/aws/ec2/cloud-ops-manager-consumer"
  retention_in_days = 7

  tags = {
    Name = "cloud-ops-manager-consumer-logs"
  }
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_consumer_xray_attach" {
  role       = aws_iam_role.cloud_ops_manager_consumer_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_ssm_association" "cloud_ops_manager_consumer_install_cw_agent" {
  name = "AmazonCloudWatch-ManageAgent-Consumer"

  targets {
    key    = "tag:Name"
    values = ["cloud-ops-manager-consumer"]
  }

  parameters = {
    action                            = "configure"
    mode                              = "ec2"
    optionalConfigurationLocation     = "/CloudOpsManager/CloudWatchAgentConfig-Consumer"
    optionalConfigurationLocationType = "ssm"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cloud_ops_manager_consumer_ssm_managed_core_attach
  ]
}

resource "aws_ssm_association" "cloud_ops_manager_consumer_install_xray" {
  name = "AWS-ConfigureAWSPackage"

  targets {
    key    = "tag:Name"
    values = ["cloud-ops-manager-consumer"]
  }

  parameters = {
    action = "Install"
    name   = "AwsXRayDaemon"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cloud_ops_manager_consumer_ssm_managed_core_attach
  ]
}