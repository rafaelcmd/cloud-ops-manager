# =============================================================================
# DATADOG INTEGRATION OUTPUTS
# Outputs for Datadog Lambda forwarder identification and references
# =============================================================================

output "datadog_forwarder_arn" {
  description = "The ARN of the Datadog Lambda forwarder"
  value       = module.datadog_forwarder.datadog_forwarder_arn
}

output "datadog_forwarder_name" {
  description = "The name of the Datadog Lambda forwarder"
  value       = module.datadog_forwarder.function_name
}

# =============================================================================
# API GATEWAY OUTPUTS
# Outputs for API Gateway access and identification
# =============================================================================

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.api_gateway_id
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = module.api_gateway.api_gateway_invoke_url
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = module.api_gateway.api_gateway_execution_arn
}

output "vpc_link_id" {
  description = "ID of the VPC Link"
  value       = module.api_gateway.vpc_link_id
}
