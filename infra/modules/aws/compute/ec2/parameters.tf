resource "aws_ssm_parameter" "cloud_ops_manager_api_ec2_host" {
  name  = "/CLOUD_OPS_MANAGER_API/EC2_PUBLIC_IP"
  type  = "String"
  value = aws_instance.cloud_ops_manager_api_ec2.public_ip
}

resource "aws_ssm_parameter" "cloud_ops_manager_api_ec2_username" {
  name  = "/CLOUD_OPS_MANAGER_API/EC2_USERNAME"
  type  = "String"
  value = "ec2-user"
}

resource "aws_ssm_parameter" "cloud_ops_manager_api_ec2_instance_id" {
  name  = "/CLOUD_OPS_MANAGER_API/EC2_INSTANCE_ID"
  type  = "String"
  value = aws_instance.cloud_ops_manager_api_ec2.id
}

resource "aws_ssm_parameter" "cloud_ops_manager_consumer_ec2_instance_id" {
  name  = "/CLOUD_OPS_MANAGER_CONSUMER/EC2_INSTANCE_ID"
  type  = "String"
  value = aws_instance.cloud_ops_manager_consumer_ec2.id
}

resource "aws_ssm_parameter" "cloud_ops_manager_api_cloudwatch_agent_config" {
  name = "/CloudOpsManager/CloudWatchAgentConfig-API"
  type = "String"
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                = "root"
    },
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/cloud-ops-manager-api.log"
              log_group_name  = "/aws/ec2/cloud-ops-manager-api"
              log_stream_name = "cloud-ops-manager-api-{instance_id}"
            }
          ]
        }
      }
    },
    metrics = {
      append_dimensions = {
        InstanceId = "{InstanceId}"
      },
      metrics_collected = {
        cpu = {
          measurement = [
            "cpu_usage_idle",
            "cpu_usage_user",
            "cpu_usage_system"
          ],
          metrics_collection_interval = 60
        }
      }
    }
  })
}

resource "aws_ssm_parameter" "cloud_ops_manager_consumer_cloudwatch_agent_config" {
  name = "/CloudOpsManager/CloudWatchAgentConfig-Consumer"
  type = "String"
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                = "root"
    },
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/cloud-ops-manager-consumer.log"
              log_group_name  = "/aws/ec2/cloud-ops-manager-consumer"
              log_stream_name = "cloud-ops-manager-consumer-{instance_id}"
            }
          ]
        }
      }
    },
    metrics = {
      append_dimensions = {
        InstanceId = "{InstanceId}"
      },
      metrics_collected = {
        cpu = {
          measurement = [
            "cpu_usage_idle",
            "cpu_usage_user",
            "cpu_usage_system"
          ],
          metrics_collection_interval = 60
        }
      }
    }
  })
}

resource "aws_ssm_parameter" "cloud_ops_manager_api_adot_collector_xray_config" {
  name  = "/CloudOpsManager/ADOTCollectorConfig-API"
  type  = "String"
  value = <<-EOT
    receivers:
        otlp:
          protocols:
            grpc:
            http:

      exporters:
        awsxray:

      service:
        pipelines:
          traces:
            receivers: [otlp]
            exporters: [awsxray]
  EOT
}

resource "aws_ssm_parameter" "cloud_ops_manager_consumer_adot_collector_xray_config" {
  name  = "/CloudOpsManager/ADOTCollectorConfig-Consumer"
  type  = "String"
  value = <<-EOT
    receivers:
        otlp:
          protocols:
            grpc:
            http:

      exporters:
        awsxray:

      service:
        pipelines:
          traces:
            receivers: [otlp]
            exporters: [awsxray]
  EOT
}
