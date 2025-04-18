output "cloud_ops_manager_api_deployment_execution_arn" {
  value = "arn:aws:execute-api:us-east-1:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.cloud_ops_manager_api.id}"
}