# An internal Network Load Balancer, its target group and its listener. This is
# the seam between the two halves of the request path: the API Gateway VPC Link
# targets the load balancer from outside the cluster, and the AWS Load Balancer
# Controller registers Fargate pod IPs into the target group from inside it.
#
# The target group is Terraform-owned rather than controller-created so its ARN
# is a stable value other stacks can reference. It holds no targets at apply
# time; a TargetGroupBinding in /k8s/api fills it.

resource "aws_lb" "this" {
  name               = var.nlb_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  subnets            = var.subnets

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-${var.nlb_name}"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_lb_target_group" "this" {
  name        = var.target_group_name
  port        = var.target_group_port
  protocol    = var.target_group_protocol
  vpc_id      = var.vpc_id
  target_type = var.target_type

  health_check {
    enabled             = var.health_check_enabled
    protocol            = var.health_check_protocol
    port                = var.health_check_port
    path                = var.health_check_path
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
  }

  # A target group cannot be deleted while a listener forwards to it, so any
  # change forcing replacement deadlocks without this.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-${var.target_group_name}"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = var.listener_action_type
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-${var.listener_port}"
    Project     = var.project
    Environment = var.environment
  })
}
