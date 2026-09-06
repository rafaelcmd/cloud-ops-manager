# Registers this AWS account with Datadog and creates the role Datadog assumes
# to read it. Ordering matters and is explained above the integration resource
# below: Datadog generates the External Id, so the integration must exist before
# the role whose trust policy pins it.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# The Datadog side of the AWS integration, which is what lets Datadog crawl the
# account for infrastructure metrics and resource inventory.
#
# This resource is created before the IAM role, not after. It references the
# role only by name, as a plain string, and Datadog responds with the External
# Id it will present when assuming that role. The role's trust policy is then
# built from that generated Id. A role created first with a self-chosen Id
# would reject Datadog's AssumeRole calls.
resource "datadog_integration_aws_account" "this" {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = data.aws_partition.current.partition

  aws_regions {
    include_only = [var.aws_region]
  }

  auth_config {
    aws_auth_config_role {
      role_name = var.role_name
    }
  }

  # Logs reach Datadog through the OTel Collector's `datadog` exporter, not
  # through a CloudWatch Lambda forwarder. The provider requires the block
  # regardless, so it stays with no forwarder configured.
  logs_config {
    lambda_forwarder {
      lambdas = []
      sources = []
    }
  }

  traces_config {
    xray_services {
      include_all = true
    }
  }

  metrics_config {
    namespace_filters {
      include_only = [
        "AWS/ApiGateway",
        "AWS/ApplicationELB",
        "AWS/AutoScaling",
        "AWS/Cognito",
        "AWS/DynamoDB",
        "AWS/EC2",
        "AWS/ELB",
        "AWS/Lambda",
        "AWS/NetworkELB",
        "AWS/RDS",
        "AWS/S3",
        "AWS/SNS",
        "AWS/SQS",
        "AWS/Usage"
      ]
    }
  }

  # extended_collection populates Datadog's Resource Catalog and additionally
  # requires the SecurityAudit managed policy, attached in the aws_integration
  # module.
  resources_config {
    cloud_security_posture_management_collection = false
    extended_collection                          = true
  }
}

# IAM role Datadog assumes to crawl the account. Its trust policy pins
# sts:ExternalId to the Datadog-generated value exported by the integration
# resource above.
module "aws_integration" {
  source = "../aws/datadog_integration"

  role_name   = var.role_name
  external_id = datadog_integration_aws_account.this.auth_config.aws_auth_config_role.external_id
  environment = var.environment
  project     = var.project
}
