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
          "ssm:GetParametersByPath"
        ]
        Resource = aws_ssm_parameter.cloud_ops_manager_api_cloudwatch_agent_config.arn
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
  name = "AWS-ConfigureAWSPackage"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloud_ops_manager_api_ec2.id]
  }

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }

  depends_on = [
    aws_instance.cloud_ops_manager_api_ec2
  ]
}

resource "null_resource" "wait_for_api_cloudwatch_agent" {
  provisioner "local-exec" {
    command = "sleep 120"
  }

  depends_on = [
    aws_ssm_association.cloud_ops_manager_api_install_cw_agent
  ]
}

resource "aws_ssm_association" "cloud_ops_manager_api_configure_cw_agent" {
  name = "AmazonCloudWatch-ManageAgent"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloud_ops_manager_api_ec2.id]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationLocation = "/CloudOpsManager/CloudWatchAgentConfig-API"
  }

  depends_on = [
    null_resource.wait_for_api_cloudwatch_agent
  ]
}

resource "aws_ssm_document" "cloud_ops_manager_api_adot_install_document" {
  name          = "CloudOpsManagerAPIADOTInstall"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install ADOT on CloudOpsManager API EC2 instance"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "installADOT"
        inputs = {
          runCommand = [
            "sudo yum update -y",
            "curl -O https://aws-otel-collector.s3.amazonaws.com/aws-otel-collector-latest-linux-amd64.rpm",
            "sudo rpm -Uvh ./aws-otel-collector-latest-linux-amd64.rpm",
            "sudo systemctl enable aws-otel-collector",
            "sudo systemctl start aws-otel-collector"
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "cloud_ops_manager_api_adot_install" {
  name = aws_ssm_document.cloud_ops_manager_api_adot_install_document.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloud_ops_manager_api_ec2.id]
  }
}

resource "aws_ssm_association" "cloud_ops_manager_api_adot_config" {
  name = "AmazonCloudWatch-ManageAgent"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloud_ops_manager_api_ec2.id]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationLocation = "/CloudOpsManager/ADOTCollectorConfig-API"
  }
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
          "ssm:GetParametersByPath"
        ]
        Resource = [
          var.provisioner_consumer_sqs_queue_parameter_arn,
          aws_ssm_parameter.cloud_ops_manager_consumer_cloudwatch_agent_config.arn
        ]
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
  name = "AWS-ConfigureAWSPackage"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloud_ops_manager_consumer_ec2.id]
  }

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }

  depends_on = [
    aws_instance.cloud_ops_manager_consumer_ec2
  ]
}

resource "null_resource" "wait_for_consumer_cloudwatch_agent" {
  provisioner "local-exec" {
    command = "sleep 120"
  }

  triggers = {
    nat_gateway_id             = var.nat_gateway_id
    route_table_association_id = var.route_table_association_id
  }

  depends_on = [
    aws_ssm_association.cloud_ops_manager_consumer_install_cw_agent
  ]
}

resource "aws_ssm_association" "cloud_ops_manager_consumer_configure_cw_agent" {
  name = "AmazonCloudWatch-ManageAgent"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloud_ops_manager_consumer_ec2.id]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationLocation = "/CloudOpsManager/CloudWatchAgentConfig-Consumer"
  }

  depends_on = [
    null_resource.wait_for_consumer_cloudwatch_agent
  ]
}

resource "aws_ssm_document" "cloud_ops_manager_consumer_adot_install_document" {
  name          = "CloudOpsManagerConsumerADOTInstall"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install ADOT on CloudOpsManager Consumer EC2 instance"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "installADOT"
        inputs = {
          runCommand = [
            "sudo yum update -y",
            "curl -O https://aws-otel-collector.s3.amazonaws.com/aws-otel-collector-latest-linux-amd64.rpm",
            "sudo rpm -Uvh ./aws-otel-collector-latest-linux-amd64.rpm",
            "sudo systemctl enable aws-otel-collector",
            "sudo systemctl start aws-otel-collector"
          ]
        }
      }
    ]
  })

  depends_on = [
    wait_for_consumer_cloudwatch_agent
  ]
}

resource "aws_ssm_association" "cloud_ops_manager_consumer_adot_install" {
  name = aws_ssm_document.cloud_ops_manager_consumer_adot_install_document.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloud_ops_manager_consumer_ec2.id]
  }

  depends_on = [
    aws_ssm_document.cloud_ops_manager_consumer_adot_install_document
  ]
}

resource "aws_ssm_association" "cloud_ops_manager_consumer_adot_config" {
  name = "AmazonCloudWatch-ManageAgent"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloud_ops_manager_consumer_ec2.id]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationLocation = "/CloudOpsManager/ADOTCollectorConfig-Consumer"
  }

  depends_on = [
    aws_ssm_association.cloud_ops_manager_consumer_adot_install
  ]
}