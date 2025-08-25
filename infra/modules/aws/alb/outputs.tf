# =============================================================================
# ALB MODULE OUTPUTS
# Outputs for Application Load Balancer resources
# =============================================================================

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.this.arn
}

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.this.id
}

output "lb_listener" {
  description = "ARN of the load balancer listener"
  value       = aws_lb_listener.this.arn
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.this.zone_id
}
