output "rest_api_id" {
  description = "The ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.resource_provisioner_api.id
}

output "root_resource_id" {
  description = "The root resource ID of the API Gateway"
  value       = aws_api_gateway_rest_api.resource_provisioner_api.root_resource_id
}

output "api_invoke_url" {
  description = "The base URL to invoke the API Gateway"
  value       = "http://${aws_api_gateway_rest_api.resource_provisioner_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.stage_name}"
}
