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
      image = "390844741587.dkr.ecr.ap-northeast-1.amazonaws.com/sample-dev-frontend:latest"

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
