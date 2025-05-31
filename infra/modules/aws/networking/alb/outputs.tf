output "cloud_ops_manager_api_tg_arn" {
  value = aws_lb_target_group.cloud_ops_manager_api_tg.arn
}

output "cloud_ops_manager_api_ecs_tg_arn" {
  value = aws_lb_target_group.cloud_ops_manager_api_ecs_tg.arn
}

output "cloud_ops_manager_api_ecs_listener" {
  value = aws_lb_listener.cloud_ops_manager_api_ecs_listener.arn
}

output "cloud_ops_manager_api_ecs_tg" {
  value = aws_lb_target_group.cloud_ops_manager_api_ecs_tg
}