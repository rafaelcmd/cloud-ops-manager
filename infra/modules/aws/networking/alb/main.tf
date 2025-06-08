# ------------------------------------------------------------------------------
# API EC2 Application Load Balancer and Target Group
# ------------------------------------------------------------------------------
resource "aws_lb" "cloud_ops_manager_api_alb" {
  name               = "cloud-ops-manager-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.cloud_ops_manager_api_security_group_id]
  subnets            = var.cloud_ops_manager_api_public_subnet_ids
}

resource "aws_lb_target_group" "cloud_ops_manager_api_tg" {
  name     = "cloud-ops-manager-api-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.cloud_ops_manager_vpc_id

  health_check {
    path                = "/resource-provisioner"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "cloud_ops_manager_api_listener" {
  load_balancer_arn = aws_lb.cloud_ops_manager_api_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloud_ops_manager_api_tg.arn
  }
}

# ------------------------------------------------------------------------------
# API ECS Application Load Balancer and Target Group
# ------------------------------------------------------------------------------
resource "aws_lb" "cloud_ops_manager_api_ecs_alb" {
  name               = "cloud-ops-manager-api-ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.cloud_ops_manager_ecs_alb_sg]
  subnets            = var.cloud_ops_manager_api_public_subnet_ids
}

resource "aws_lb_target_group" "cloud_ops_manager_api_ecs_tg" {
  name        = "cloud-ops-manager-api-ecs-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.cloud_ops_manager_vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "cloud_ops_manager_api_ecs_listener" {
  load_balancer_arn = aws_lb.cloud_ops_manager_api_ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloud_ops_manager_api_ecs_tg.arn
  }
}