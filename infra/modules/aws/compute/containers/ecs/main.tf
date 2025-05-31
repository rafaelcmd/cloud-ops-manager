resource "aws_ecs_cluster" "cloud_ops_manager_api_cluster" {
  name = "cloud-ops-manager-api-cluster"
}

resource "aws_iam_role" "cloud_ops_manager_api_task_role" {
  name               = "cloud-ops-manager-api-task-role"
  assume_role_policy = data.aws_iam_policy_document.cloud_ops_manager_api_assume_role_policy.json
}

data "aws_iam_policy_document" "cloud_ops_manager_api_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_api_task_role_policy" {
  role       = aws_iam_role.cloud_ops_manager_api_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "cloud_ops_manager_api_task" {
  family                   = "cloud-ops-manager-api-task"
  task_role_arn            = aws_iam_role.cloud_ops_manager_api_task_role.arn
  execution_role_arn       = aws_iam_role.cloud_ops_manager_api_task_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "cloud-ops-manager-api"
      image     = "ami-077c7efa4f912139d"
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]
    }
  ])
}