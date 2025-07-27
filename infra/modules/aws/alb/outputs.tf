output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "alb_sg_id" {
  value = aws_security_group.this.id
}

output "lb_listener" {
  value = aws_lb_listener.this.arn
}