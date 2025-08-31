# =============================================================================
# NLB MODULE OUTPUTS
# Outputs for Network Load Balancer resources
# =============================================================================

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.this.arn
}

output "lb_listener" {
  description = "ARN of the load balancer listener"
  value       = aws_lb_listener.this.arn
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.this.arn
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.this.dns_name
}

output "nlb_zone_id" {
  description = "Zone ID of the Network Load Balancer"
  value       = aws_lb.this.zone_id
}
