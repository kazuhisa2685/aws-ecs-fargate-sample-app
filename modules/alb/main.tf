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

# ターゲットグループ　フロントエンド１
resource "aws_lb_target_group" "frontend_target_1" {
  name        = "${var.project}-${var.environment}-frontend-target-1"
  port        = 1500
  protocol    = "HTTP"
  target_type = "ip" #Fargateでは、タスクごとにENIが作成され、タスク自身がVPC内のプライベートIPアドレスを持つため
  vpc_id      = var.vpc_id

  health_check {
    path                = "/_stcore/health"
    interval            = 60
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-frontend-target-1"
    Environment = var.environment
    Project     = var.project
  }
}

# ターゲットグループ　フロントエンド２
resource "aws_lb_target_group" "frontend_target_2" {
  name        = "${var.project}-${var.environment}-frontend-target-2"
  port        =  1501
  protocol    = "HTTP"
  target_type = "ip" #Fargateでは、タスクごとにENIが作成され、タスク自身がVPC内のプライベートIPアドレスを持つため
  vpc_id      = var.vpc_id

  health_check {
    path                = "/_stcore/health"
    interval            = 60
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-frontend-target-2"
    Environment = var.environment
    Project     = var.project
  }
}

# 本番リスナー　フロントエンド
resource "aws_lb_listener" "frontend_production_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = "1500"
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.frontend_target_1.arn
        weight = 100
      }

      target_group {
        arn    = aws_lb_target_group.frontend_target_2.arn
        weight = 0
      }
    }
  }
}

#本番リスナールール　フロントエンド
resource "aws_lb_listener_rule" "frontend_production_listener_rule" {
  listener_arn = aws_lb_listener.frontend_production_listener.arn
  priority     = 100

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.frontend_target_1.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.frontend_target_2.arn
        weight = 0
      }
    }
  }

  lifecycle {
    ignore_changes = [action]
  }

  condition {
    path_pattern {
      values = ["*"] # 全すべてのパスを対象にする
    }
  }
}

# テストリスナー　フロントエンド
resource "aws_lb_listener" "frontend_test_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = "1501"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_target_2.arn
  }
}

# テスト用リスナールール　フロントエンド
resource "aws_lb_listener_rule" "frontend_test_listener_rule" {
  listener_arn = aws_lb_listener.frontend_test_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_target_2.arn
  }

  lifecycle {
    ignore_changes = [action]
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}


# ターゲットグループ　バックエンド１
resource "aws_lb_target_group" "backend_target_1" {
  name        = "${var.project}-${var.environment}-backend-target-1"
  port        = 8000
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
    Name        = "${var.project}-${var.environment}-backend-target-1"
    Environment = var.environment
    Project     = var.project
  }
}

# ターゲットグループ　バックエンド２
resource "aws_lb_target_group" "backend_target_2" {
  name        = "${var.project}-${var.environment}-backend-target-2"
  port        = 8001
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
    Name        = "${var.project}-${var.environment}-backend-target-2"
    Environment = var.environment
    Project     = var.project
  }
}

# 本番リスナー　バックエンド
resource "aws_lb_listener" "backend_production_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.backend_target_1.arn
        weight = 100
      }

      target_group {
        arn    = aws_lb_target_group.backend_target_2.arn
        weight = 0
      }
    }
  }
}

#本番リスナールール　バックエンド
resource "aws_lb_listener_rule" "backend_production_listener_rule" {
  listener_arn = aws_lb_listener.backend_production_listener.arn
  priority     = 100

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.backend_target_1.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.backend_target_2.arn
        weight = 0
      }
    }
  }

  lifecycle {
    ignore_changes = [action]
  }

  condition {
    path_pattern {
      values = ["*"] # 全すべてのパスを対象にする
    }
  }
}

# テストリスナー　バックエンド
resource "aws_lb_listener" "backend_test_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = "8001"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_target_2.arn
  }
}

# テスト用リスナールール　バックエンド
resource "aws_lb_listener_rule" "backend_test_listener_rule" {
  listener_arn = aws_lb_listener.backend_test_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_target_2.arn
  }

  lifecycle {
    ignore_changes = [action]
  }
  condition {
    path_pattern {
      values = ["api/*"]
    }
  }
}

