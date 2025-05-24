output "cloud_ops_manager_api_autoscaling_group_name" {
  value = aws_autoscaling_group.cloud_ops_manager_api_autoscaling_group.name
}

output "cloud_ops_manager_api_scale_out_policy_arn" {
  value = aws_autoscaling_policy.cloud_ops_manager_api_scale_out.arn
}