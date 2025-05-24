resource "aws_cloudwatch_metric_alarm" "cloud_ops_manager_api_high_cpu" {
  alarm_name          = "${var.cloud_ops_manager_api_autoscaling_group_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = var.cloud_ops_manager_api_autoscaling_group_name
  }

  alarm_description = "This alarm triggers when CPU usage exceeds 70%"
  alarm_actions     = [var.cloud_ops_manager_api_scale_out_policy_arn]
}