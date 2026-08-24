###############################################
# load balancer for blue green deployment
###############################################

# ロードバランサー
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-lb"
  internal           = false #インターネット向けという意味
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
resource "aws_lb_target_group" "target-1" {
  name        = "${var.project}-${var.environment}-target-1"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip" #Fargateでは、タスクごとにENIが作成され、タスク自身がVPC内のプライベートIPアドレスを持つため
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    interval            = 60
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-target-1"
    Environment = var.environment
    Project     = var.project
  }
}

# ターゲットグループ(緑)
resource "aws_lb_target_group" "target-2" {
  name        = "${var.project}-${var.environment}-target-2"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip" #Fargateでは、タスクごとにENIが作成され、タスク自身がVPC内のプライベートIPアドレスを持つため
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    interval            = 60
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-target-2"
    Environment = var.environment
    Project     = var.project
  }
}

# 本番リスナー
resource "aws_lb_listener" "production_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.target-1.arn
        weight = 100
      }

      target_group {
        arn    = aws_lb_target_group.target-2.arn
        weight = 0
      }
    }
  }
}

#本番リスナールール
resource "aws_lb_listener_rule" "production_rule" {
  listener_arn = aws_lb_listener.production_listener.arn
  priority     = 100

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.target-1.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.target-2.arn
        weight = 0
      }
    }
  }

  condition {
    path_pattern {
      values = ["*"] # 全すべてのパスを対象にする
    }
  }
}

#テストリスナー
resource "aws_lb_listener" "test_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-2.arn
  }
}

# テスト用リスナールール（★これもECSのadvanced_configurationに渡すやつ）
resource "aws_lb_listener_rule" "test_rule" {
  listener_arn = aws_lb_listener.test_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-2.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}