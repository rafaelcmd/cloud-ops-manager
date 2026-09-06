output "web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.api.arn
}

output "web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.api.id
}

output "web_acl_name" {
  description = "Name of the WAF Web ACL"
  value       = aws_wafv2_web_acl.api.name
}

output "web_acl_capacity" {
  description = "WCU capacity of the WAF Web ACL"
  value       = aws_wafv2_web_acl.api.capacity
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for WAF logs"
  value       = var.enable_logging ? aws_cloudwatch_log_group.waf[0].arn : null
}
