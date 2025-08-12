# CloudWatch Log Subscription to forward ECS logs to Datadog
data "terraform_remote_state" "datadog_integration" {
  backend = "s3"
  config = {
    bucket = "cloudops-manager-terraform-state"
    key    = "shared/datadog/terraform.tfstate"
    region = "us-east-1"
  }
}

# Subscribe CloudWatch logs to Datadog forwarder
resource "aws_cloudwatch_log_subscription_filter" "datadog_log_subscription_api" {
  depends_on      = [aws_cloudwatch_log_group.ecs_api]
  destination_arn = data.terraform_remote_state.datadog_integration.outputs.datadog_forwarder_arn
  filter_pattern  = ""
  log_group_name  = aws_cloudwatch_log_group.ecs_api.name
  name            = "datadog-log-subscription-api"
}

resource "aws_cloudwatch_log_subscription_filter" "datadog_log_subscription_agent" {
  depends_on      = [aws_cloudwatch_log_group.datadog_agent]
  destination_arn = data.terraform_remote_state.datadog_integration.outputs.datadog_forwarder_arn
  filter_pattern  = ""
  log_group_name  = aws_cloudwatch_log_group.datadog_agent.name
  name            = "datadog-log-subscription-agent"
}
