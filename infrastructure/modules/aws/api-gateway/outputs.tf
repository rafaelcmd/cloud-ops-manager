output "rest_api_id" {
  description = "The ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.resource_provisioner_api.id
}

output "root_resource_id" {
  description = "The root resource ID of the API Gateway"
  value       = aws_api_gateway_rest_api.resource_provisioner_api.root_resource_id
}
