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
      image = "390844741587.dkr.ecr.ap-northeast-1.amazonaws.com/sample-dev-frontend:${var.frontend_image_tag}"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          # 上で作成したロググループの名前を参照
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_frontend_log_group.name
          "awslogs-region"        = "ap-northeast-1"
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

resource "aws_cloudwatch_log_group" "ecs_frontend_log_group" {
  # タスク定義の logConfiguration で指定する awslogs-group の名前と一致させます
  name              = "/ecs/sample-dev-frontend-task"
  retention_in_days = 30

  tags = {
    Environment = "dev"
    Application = "sample-frontend"
  }
}