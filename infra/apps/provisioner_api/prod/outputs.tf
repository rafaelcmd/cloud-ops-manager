output "datadog_forwarder_arn" {
  description = "The ARN of the Datadog Lambda forwarder"
  value       = module.datadog_forwarder.datadog_forwarder_arn
}

output "datadog_forwarder_name" {
  description = "The name of the Datadog Lambda forwarder"
  value       = module.datadog_forwarder.function_name
}
