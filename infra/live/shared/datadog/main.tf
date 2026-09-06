# The AWS side of the Datadog account integration, plus the API key every
# telemetry component reads.
#
# The key is passed in as a variable and stored as a SecureString. It is the one
# secret this repository's Terraform holds a value for, supplied by CI from the
# DD_API_KEY repository secret rather than committed.

module "datadog" {
  source = "../../../modules/datadog"

  aws_region  = var.aws_region
  role_name   = var.role_name
  environment = var.environment
  project     = var.project
}

resource "aws_ssm_parameter" "datadog_api_key" {
  name        = "/${var.project}/${var.environment}/datadog/api_key"
  description = "Datadog API Key"
  type        = "SecureString"
  value       = var.datadog_api_key

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}
