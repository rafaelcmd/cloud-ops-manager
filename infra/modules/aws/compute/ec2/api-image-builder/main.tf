terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

terraform {
  cloud {

    organization = "cloudops-manager-org"

    workspaces {
      name = "cloudops-manager-api-image-builder"
    }
  }
}

resource "aws_vpc" "cloudops_manager_api_image_builder_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "cloudops-manager-api-image-builder-vpc"
  }
}

resource "aws_subnet" "image_builder_subnet" {
  vpc_id                  = aws_vpc.cloudops_manager_api_image_builder_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "cloudops-manager-api-image-builder-subnet"
  }
}

resource "aws_internet_gateway" "cloudops_manager_api_image_builder_igw" {
  vpc_id = aws_vpc.cloudops_manager_api_image_builder_vpc.id

  tags = {
    Name = "cloudops-manager-api-image-builder-igw"
  }
}

resource "aws_route_table" "image_builder_rt" {
  vpc_id = aws_vpc.cloudops_manager_api_image_builder_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloudops_manager_api_image_builder_igw.id
  }

  tags = {
    Name = "cloudops-manager-api-image-builder-rt"
  }
}

resource "aws_route_table_association" "cloudops_manager_api_image_builder_rta" {
  subnet_id      = aws_subnet.image_builder_subnet.id
  route_table_id = aws_route_table.image_builder_rt.id
}

resource "aws_security_group" "image_builder_sg" {
  name        = "cloudops-manager-api-image-builder-sg"
  description = "Allow SSH, HTTP, HTTPS"
  vpc_id      = aws_vpc.cloudops_manager_api_image_builder_vpc.id

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
    Name = "cloudops-manager-api-image-builder-sg"
  }
}

resource "aws_iam_role" "cloudops_manager_api_image_builder_role" {
  name = "cloud-ops-manager-api-image-builder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudops_manager_api_ssm_policy" {
  role       = aws_iam_role.cloudops_manager_api_image_builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudops_manager_api_image_builder_policy" {
  role       = aws_iam_role.cloudops_manager_api_image_builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy" "cloudops_manager_api_adot_permissions" {
  name = "cloud-ops-adot-permissions"
  role = aws_iam_role.cloudops_manager_api_image_builder_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cloudops_manager_api_image_builder_profile" {
  name = "cloud-ops-manager-api-imagebuilder-profile"
  role = aws_iam_role.cloudops_manager_api_image_builder_role.name
}

resource "aws_imagebuilder_component" "cloudops_manager_api_adot_install_and_configure" {
  name        = "cloudops-manager-api-install-adot-collector"
  platform    = "Linux"
  version     = "1.0.0"
  description = "Install and configure AWS OTel Collector for Logs, Metrics, and Traces"

  data = <<-DOC
name: InstallAndConfigureADOT
description: Install and configure ADOT for CloudWatch and X-Ray
schemaVersion: 1.0
phases:
  - name: build
    steps:
      - name: InstallSSMAgent
        action: ExecuteBash
        inputs:
          commands:
            - dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
            - systemctl enable amazon-ssm-agent
            - systemctl start amazon-ssm-agent

      - name: InstallADOT
        action: ExecuteBash
        inputs:
          commands:
            - dnf install -y unzip curl --allowerasing
            - cd /tmp
            - curl -LO https://aws-otel-collector.s3.amazonaws.com/amazon_linux/amd64/latest/aws-otel-collector.rpm
            - rpm -Uvh aws-otel-collector.rpm

      - name: ConfigureADOT
        action: ExecuteBash
        inputs:
          commands:
            - mkdir -p /opt/aws/aws-otel-collector
            - |
              cat <<EOF > /opt/aws/aws-otel-collector/config.yaml
              receivers:
                otlp:
                  protocols:
                    grpc:
                    http:
                      endpoint: 0.0.0.0:4318

                filelog:
                  include: ["/var/log/cloud-ops-manager/api.log"]
                  start_at: beginning
                  operators:
                    - type: json_parser
                      id: parse-json
                      timestamp:
                        parse_from: attributes.timestamp
                        layout: '%Y-%m-%dT%H:%M:%S.%LZ'
                      severity:
                        parse_from: attributes.level
                    - type: move
                      from: body.message
                      to: body

              processors:
                batch:

              exporters:
                awsxray: {}

                awscloudwatchlogs:
                  log_group_name: /aws/cloudops-manager
                  log_stream_name: "instance-${INSTANCE_ID}"
                  region: us-east-1

              service:
                pipelines:
                  traces:
                    receivers: [otlp]
                    processors: [batch]
                    exporters: [awsxray]

                  logs:
                    receivers: [filelog]
                    processors: [batch]
                    exporters: [awscloudwatchlogs]
              EOF

      - name: SetupSystemd
        action: ExecuteBash
        inputs:
          commands:
            - |
              cat <<SERVICE > /etc/systemd/system/aws-otel-collector.service
              [Unit]
              Description=AWS OTel Collector
              After=network.target

              [Service]
              ExecStartPre=/bin/bash -c 'echo INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) > /etc/default/adot-env'
              EnvironmentFile=/etc/default/adot-env
              ExecStart=/opt/aws/aws-otel-collector/bin/aws-otel-collector --config /opt/aws/aws-otel-collector/config.yaml
              Restart=always

              [Install]
              WantedBy=multi-user.target
              SERVICE
            - systemctl daemon-reload
            - systemctl enable aws-otel-collector
            - systemctl start aws-otel-collector
DOC
}

resource "aws_imagebuilder_image_recipe" "cloudops_manager_api_image_builder_recipe" {
  name         = "cloudops-manager-api-image-builder-recipe"
  version      = "1.0.0"
  parent_image = "ami-0953476d60561c955"

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

  component {
    component_arn = aws_imagebuilder_component.cloudops_manager_api_adot_install_and_configure.arn
  }

  description = "CloudOps Manager API Base Image"
}

resource "aws_imagebuilder_infrastructure_configuration" "cloudops_manager_api_image_builder_infra" {
  name                          = "cloud-opsmanager-api-infra-config"
  instance_profile_name         = aws_iam_instance_profile.cloudops_manager_api_image_builder_profile.name
  subnet_id                     = aws_subnet.image_builder_subnet.id
  security_group_ids            = [aws_security_group.image_builder_sg.id]
  terminate_instance_on_failure = true

  tags = {
    Name = "cloud-opsmanager-apiimage-builder-infra"
  }
}

resource "aws_imagebuilder_image_pipeline" "cloudops_manager_api_image_builder_pipeline" {
  name                             = "cloud-ops-manager-api-pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.cloudops_manager_api_image_builder_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.cloudops_manager_api_image_builder_infra.arn

  tags = {
    Name = "cloud-ops-manager-api-pipeline"
  }
}
