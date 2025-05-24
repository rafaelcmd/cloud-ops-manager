resource "aws_iam_role" "image_builder_api_role" {
  name = "cloud-ops-manager-api-image-builder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "imagebuilder.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "image_builder_api_role_policy" {
  role       = aws_iam_role.image_builder_api_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSImageBuilderServiceRole"
}

resource "aws_imagebuilder_component" "cloud_ops_manager_api_install_agents" {
  name        = "cloud-ops-manager-api-agents"
  platform    = "Linux"
  version     = "1.0.0"
  description = "Install CloudWatch, X-Ray, ADOT"

  data = <<EOT
  name: InstallMonitoringAgents
  description: Install CloudWatch, X-Ray, ADOT agents
  schemaVersion: 1.0
  phases:
    -name: build
      steps:
        - name: InstallCloudWatchAgent
           action: ExecuteBash
           inputs:
              commands:
                - yum install -y amazon-cloudwatch-agent
                - systemctl enable amazon-cloudwatch-agent
                - systemctl start amazon-cloudwatch-agent
        - name: InstallXRayDaemon
           action: ExecuteBash
           inputs:
              commands:
                - yum install -y xray
                - systemctl enable xray
                - systemctl start xray
        - name: InstallADOT
           action: ExecuteBash
           inputs:
              commands:
                - cd /tmp
                - curl -fLO https://aws-otel-collector.s3.amazonaws.com/amazon_linux/amd64/latest/aws-otel-collector.rpm
                - rpm -Uvh aws-otel-collector.rpm
                - systemctl enable aws-otel-collector
  EOT
}

resource "aws_imagebuilder_image_recipe" "cloud_ops_manager_api_recipe" {
  name         = "cloud-ops-manager-api-recipe"
  version      = "1.0.0"
  parent_image = "ami-08b5b3a93ed654d19"

  block_device_mapping {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  component {
    component_arn = aws_imagebuilder_component.cloud_ops_manager_api_install_agents.arn
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "cloud_ops_manager_api_infra_config" {
  name                          = "cloud-ops-manager-api-infra-config"
  instance_profile_name         = "imagebuilder-instance-profile"
  security_group_ids            = [var.cloud_ops_manager_api_sg_id]
  subnet_id                     = var.cloud_ops_manager_api_subnet_id
  terminate_instance_on_failure = true
}

resource "aws_imagebuilder_image_pipeline" "cloud_ops_manager_api_pipeline" {
  name                             = "cloud-ops-manager-api-pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.cloud_ops_manager_api_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.cloud_ops_manager_api_infra_config.arn

  tags = {
    Name = "cloud-ops-manager-api-pipeline"
  }
}