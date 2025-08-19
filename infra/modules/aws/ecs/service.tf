resource "aws_ecs_service" "api_service" {
  name                               = "${var.service_name}-service"
  cluster                            = aws_ecs_cluster.cloudops_cluster.id
  task_definition                    = aws_ecs_task_definition.api.arn
  desired_count                      = var.desired_count
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  launch_type                        = "FARGATE"
  platform_version                   = var.platform_version
  force_new_deployment               = var.force_new_deployment

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.api_ecs_task_sg.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.app_container_name
    container_port   = var.container_port
  }

  depends_on = [
    var.lb_listener
  ]

  # Force deployment when task definition changes
  triggers = {
    task_definition_arn = aws_ecs_task_definition.api.arn
  }

  tags = merge(var.tags, {
    Datadog           = "monitored"
    "datadog:service" = var.service_name
    "datadog:env"     = var.environment
    "datadog:version" = var.app_version
    Project           = var.project
    Environment       = var.environment
  })
}