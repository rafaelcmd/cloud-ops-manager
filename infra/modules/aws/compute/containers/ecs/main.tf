resource "aws_ecs_cluster" "cloud_ops_manager_api_cluster" {
  name = "cloud-ops-manager-api-cluster"
}

resource "aws_iam_role" "cloud_ops_manager_api_ecs_task_execution_role" {
  name = "cloud-ops-manager-api-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_api_ecs_task_execution_role_policy" {
  role       = aws_iam_role.cloud_ops_manager_api_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "cloud_ops_manager_api_ecs_log_group" {
  name              = "/ecs/cloud-ops-manager"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "cloud_ops_manager_api_task_definition" {
  family                   = "cloud-ops-manager-api-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.cloud_ops_manager_api_ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "cloud-ops-manager-api"
      image = "${data.terraform_remote_state.cloudops-manager-ecr-repository.outputs.api_repository_url}:latest"

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.cloud_ops_manager_api_ecs_log_group.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs-api"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "cloud_ops_manager_api_ecs_service" {
  name            = "cloud-ops-manager-api-ecs-service"
  cluster         = aws_ecs_cluster.cloud_ops_manager_api_cluster.id
  task_definition = aws_ecs_task_definition.cloud_ops_manager_api_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.cloud_ops_manager_api_public_subnet_ids
    security_groups  = [var.cloud_ops_manager_api_ecs_security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.cloud_ops_manager_api_ecs_tg_arn
    container_name   = "cloud-ops-manager-api"
    container_port   = 5000
  }

  depends_on = [
    var.cloud_ops_manager_api_ecs_listener,
    var.cloud_ops_manager_api_ecs_tg,
  ]
}