resource "aws_launch_template" "cloud_ops_manager_api_launch_template" {
  name_prefix   = "cloud-ops-manager-api-"
  image_id      = "ami-08b5b3a93ed654d19"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.cloud_ops_manager_api_security_group_id]
  }
}

resource "aws_autoscaling_group" "cloud_ops_manager_api_autoscaling_group" {
  name                      = "cloud-ops-manager-api-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 2
  vpc_zone_identifier       = var.cloud_ops_manager_api_public_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [var.cloud_ops_manager_api_tg_arn]

  launch_template {
    id      = aws_launch_template.cloud_ops_manager_api_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "cloud-ops-manager-api-instance"
    propagate_at_launch = true
  }
}