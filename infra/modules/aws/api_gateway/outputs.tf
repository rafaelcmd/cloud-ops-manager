# =============================================================================
# API GATEWAY OUTPUTS
# Outputs for API Gateway identification and access
# =============================================================================

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.this.id
}

output "api_gateway_arn" {
  description = "ARN of the API Gateway"
  value       = aws_apigatewayv2_api.this.arn
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway stage"
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "api_gateway_api_endpoint" {
  description = "API endpoint URL of the API Gateway"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

# =============================================================================
# VPC LINK OUTPUTS
# Outputs for VPC Link identification
# =============================================================================

output "vpc_link_id" {
  description = "ID of the VPC Link"
  value       = aws_apigatewayv2_vpc_link.this.id
}

output "vpc_link_arn" {
  description = "ARN of the VPC Link"
  value       = aws_apigatewayv2_vpc_link.this.arn
}

# =============================================================================
# STAGE OUTPUTS
# Outputs for API Gateway stage information
# =============================================================================

output "stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_apigatewayv2_stage.this.name
}

output "stage_arn" {
  description = "ARN of the API Gateway stage"
  value       = aws_apigatewayv2_stage.this.arn
}
