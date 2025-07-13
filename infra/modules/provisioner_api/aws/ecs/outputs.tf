output "ecs_service_sg" {
  description = "Security group for the ECS service"
  value       = aws_security_group.ecs_service_sg.id
}