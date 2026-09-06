output "api_gateway_id" {
  description = "ID of the REST API Gateway"
  value       = aws_api_gateway_rest_api.this.id
}

output "api_gateway_arn" {
  description = "ARN of the REST API Gateway"
  value       = aws_api_gateway_rest_api.this.arn
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the REST API Gateway"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway stage"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "api_gateway_root_resource_id" {
  description = "Root resource ID of the REST API"
  value       = aws_api_gateway_rest_api.this.root_resource_id
}

output "vpc_link_id" {
  description = "ID of the VPC Link"
  value       = aws_api_gateway_vpc_link.this.id
}

output "vpc_link_arn" {
  description = "ARN of the VPC Link"
  value       = aws_api_gateway_vpc_link.this.arn
}

output "stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.this.stage_name
}

output "stage_arn" {
  description = "ARN of the API Gateway stage"
  value       = aws_api_gateway_stage.this.arn
}

output "stage_execution_arn" {
  description = "Execution ARN of the API Gateway stage"
  value       = aws_api_gateway_stage.this.execution_arn
}

output "api_version" {
  description = "Current API version"
  value       = var.api_version
}

output "api_base_path" {
  description = "Base path for the current API version (e.g., /v1)"
  value       = "/${var.api_version}"
}

output "deprecated_versions" {
  description = "List of deprecated API versions with their sunset dates"
  value       = var.deprecated_versions
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway_logs.arn
}
