################################################
# ECS タスク定義
################################################
resource "aws_ecs_task_definition" "ecs_frontend_taskdef" {
  family                   = "${var.project}-${var.environment}-frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/${var.project}-${var.environment}-frontend:${var.frontend_image_tag}"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_frontend_log_group.name
          "awslogs-region"        = "${data.aws_region.current.region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      portMappings = [
        {
          containerPort = 1500
          #hostPort      = 1500 #Fargateモードだとこれは動かないらしい。
          protocol = "tcp"
        }
      ]

      command = ["streamlit", "run", "app.py", "--server.port=1500", "--server.address=0.0.0.0"]
    }
  ])
}

#CWロググループはECSとの強い依存関係があるので、ここにいれる。
resource "aws_cloudwatch_log_group" "ecs_frontend_log_group" {
  # タスク定義の logConfiguration で指定する awslogs-group の名前と一致させます
  name              = "/ecs/${var.project}-${var.environment}-frontend-task"
  retention_in_days = 30

  tags = {
    Environment = "${var.project}"
    Application = "${var.environment}"
  }
}