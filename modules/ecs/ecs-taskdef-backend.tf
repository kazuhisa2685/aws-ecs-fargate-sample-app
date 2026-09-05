################################################
# ECS タスク定義
################################################
resource "aws_ecs_task_definition" "ecs_backend_taskdef" {
  family                   = "${var.project}-${var.environment}-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "main"
      image = "390844741587.dkr.ecr.ap-northeast-1.amazonaws.com/sample-dev-backend:latest"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          # 上で作成したロググループの名前を参照
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend_log_group.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      portMappings = [
        {
          name        = "backend-port" # ← service_connect_configuration.service.port_name と一致させる必要がある
          containerPort = 8000
          #hostPort      = 8080 #Fargateモードだとこれは動かないらしい。
          protocol = "tcp"
          appProtocol = "http"
        }
      ]

      command = ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"] #これがないとECSがタスクを動かしてくれない。最初に実行するものを記載しないといけない。
    }
  ])
}

resource "aws_cloudwatch_log_group" "ecs_backend_log_group" {
  # タスク定義の logConfiguration で指定する awslogs-group の名前と一致させます
  name              = "/ecs/sample-dev-backend-task"
  retention_in_days = 30
  tags = {
    Environment = "dev"
    Application = "sample-backend"
  }
}