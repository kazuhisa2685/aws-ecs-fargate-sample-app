###############################################
# load balancer for blue green deployment
###############################################

# ロードバランサ
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets = [
    var.public_subnet_ingress_id,
    var.public_subnet_ingress_id-1c
  ]

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project}-${var.environment}-lb"
    Environment = var.environment
    Project     = var.project
  }
}

# ターゲットグループ(青)
resource "aws_lb_target_group" "tg_blue" {
  name     = "${var.project}-${var.environment}-tg-blue"
  port     = 8080
  protocol = "HTTP"
  target_type = "ip" #Fargateでは、タスクごとにENIが作成され、タスク自身がVPC内のプライベートIPアドレスを持つため
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-tg-blue"
    Environment = var.environment
    Project     = var.project
  }
}

# ターゲットグループ(緑)
resource "aws_lb_target_group" "tg_green" {
  name     = "${var.project}-${var.environment}-tg-green"
  port     = 8080
  protocol = "HTTP"
  target_type = "ip" #Fargateでは、タスクごとにENIが作成され、タスク自身がVPC内のプライベートIPアドレスを持つため
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-tg-green"
    Environment = var.environment
    Project     = var.project
  }
}

# リスナー設定
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.tg_blue.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.tg_green.arn
        weight = 0
      }
    }
  }

# デプロイ時に ECS が weight を書き換えるため、Terraform での競合を防止する
  lifecycle {
    ignore_changes = [
      default_action,
    ]
  }
}

# リスナールール（本番）: ALB の場合は Listener Rule ARN を ECS に渡す必要がある
resource "aws_lb_listener_rule" "prod" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.tg_blue.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.tg_green.arn
        weight = 0
      }
    }
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}
# ###############################################
# # ECS サービス (組み込み Blue/Green 設定)
# # fargateだと、IPで分けることになるからポートで転送先を明示的に変える必要はない？っぽい
# ###############################################
# resource "aws_ecs_service" "app" {
#   name            = "${var.project}-${var.environment}-service"
#   cluster         = var.ecs_cluster_id
#   task_definition = aws_ecs_task_definition.app.arn
#   desired_count   = 2
#   launch_type     = "FARGATE"

#   # ★ ネイティブ Blue/Green デプロイの設定
#   deployment_configuration {
#     strategy             = "BLUE_GREEN"
#     bake_time_in_minutes = 5 # 切り替え後の監視時間（分）。この間に問題があれば自動/手動ロールバック可能
#   }

#   # ターゲットグループ（Blue と Green の両方を関連付け）
#   load_balancer {
#     target_group_arn = aws_lb_target_group.tg_blue.arn
#     container_name   = "app"
#     container_port   = 8080
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.tg_green.arn
#     container_name   = "app"
#     container_port   = 8080
#   }

#   network_configuration {
#     subnets         = [var.private_subnet_id, var.private_subnet_id-1c]
#     security_groups = [var.fargate_frontend_sg_id]
#   }

#   depends_on = [aws_lb_listener.http]
# }