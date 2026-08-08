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