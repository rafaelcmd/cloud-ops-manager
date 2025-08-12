resource "aws_ecs_service" "api_service" {
  name                               = "resource-provisioner-api-service"
  cluster                            = aws_ecs_cluster.cloudops_cluster.id
  task_definition                    = aws_ecs_task_definition.api.arn
  desired_count                      = 4
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  force_new_deployment               = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.api_ecs_task_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "resource-provisioner-api"
    container_port   = 5000
  }

  depends_on = [
    var.lb_listener
  ]

  # Force deployment when task definition changes
  triggers = {
    task_definition_arn = aws_ecs_task_definition.api.arn
  }

  tags = {
    Datadog                = "monitored"
    "datadog:service"      = "resource-provisioner-api"
    "datadog:env"          = "prod"
    "datadog:version"      = "1.0.0"
    Project                = "cloudops"
    Environment            = "prod"
  }
}