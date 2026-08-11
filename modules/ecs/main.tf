###############################################
# ECS クラスター
###############################################
resource "aws_ecs_cluster" "ecs_frontend_cluster" {
  name = "${var.project}-${var.environment}-cluster"

  # Container Insights (メトリクス監視) を有効化（任意）
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-cluster"
    Environment = var.environment
    Project     = var.project
  }
}

# キャパシティプロバイダーの設定 (FARGATE / FARGATE_SPOT)
resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_capacity_providers" {
  cluster_name = aws_ecs_cluster.ecs_frontend_cluster.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 1
    capacity_provider = "FARGATE"
  }
}

################################################
# ECS サービス用
################################################
resource "aws_ecs_service" "ecs_frontend_service" {
  name            = "${var.project}-${var.environment}-service"
  cluster         = aws_ecs_cluster.ecs_frontend_cluster.id
  task_definition = aws_ecs_task_definition.ecs_frontend_taskdef.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  deployment_configuration {
    strategy             = "BLUE_GREEN"     # 組み込み Blue/Green を使用
    bake_time_in_minutes = 5                # 新バージョン(Green)へ切り替えた後、旧タスク(Blue)を削除するまでの待機時間（分）
  }
  load_balancer {
    container_name   = "app"
    container_port   = 8080

    # 組み込み Blue/Green 用の設定
    advanced_configuration {
      alternate_target_group_arn    = "${var.tg_green_arn}"       # 代替（サブ/Green側）のターゲットグループ
      production_listener_rule      = "${var.production_listener_rule_arn}"      # 本番トラフィックをルーティングしている ALB リスナールールの ARN（ALB では Rule ARN が必要）
      # test_listener_rule          = "${var.test_listener_rule_arn}"            # テストトラフィック用（オプション）
      role_arn                      = aws_iam_role.ecs_alb_service_role.arn  # ECS が ALB 設定を操作するための IAM ロール
    }
    target_group_arn = "${var.tg_blue_arn}"  # メイン（プライマリ/Blue側）のターゲットグループ
  }

  network_configuration {
    subnets         = [var.private_subnet_id, var.private_subnet_id-1c]
    security_groups = [var.fargate_frontend_sg_id]
  }
  lifecycle {
    ignore_changes = [
      # デプロイごとに使用されるターゲットグループ（Blue/Green）が入れ替わるため無効化
      load_balancer,
      # CI/CD パイプライン（GitHub Actions等）側でタスク定義を更新する場合に指定
      task_definition,
    ]
  }
  
  #depends_on = [aws_lb_target_group.tg_blue]
}

################################################
# ECS タスク定義
################################################
resource "aws_ecs_task_definition" "ecs_frontend_taskdef" {
  family                   = "${var.project}-${var.environment}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MiB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "390844741587.dkr.ecr.ap-northeast-1.amazonaws.com/sbcntr-frontend-app:latest" # 実際はECR等のURLを指定
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      # logConfiguration = {
      #   logDriver = "awslogs"
      #   options = {
      #     "awslogs-group"         = aws_cloudwatch_log_group.ecs_app.name
      #     "awslogs-region"        = "ap-northeast-1"
      #     "awslogs-stream-prefix" = "ecs"
      #   }
      # }
    }
  ])
}

###############################################
# IAMロール関連
###############################################

# A. タスク実行ロール (ECRからの画像引き出しや CloudWatch Logs への書き込み用)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# B. ECSがALBを直接操作するためのロール
resource "aws_iam_role" "ecs_alb_service_role" {
  name = "${var.project}-${var.environment}-ecs-alb-service-role"

  #信頼ポリシー
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}

# アイデンティティポリシーを追加(これがないと、ECSがALBのリスナーやターゲットグループを切り替えられない)
resource "aws_iam_role_policy" "ecs_alb_service_role_policy" {
  name = "${var.project}-${var.environment}-ecs-alb-service-policy"
  role = aws_iam_role.ecs_alb_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeListeners"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS が ALB リスナーやターゲットグループを切り替えるための権限
#必要かどうか検討中。これがあってもうまくいかなかったので、上記のポリシーを追加した。
#"elasticloadbalancing:ModifyRule"がなくてNGになった
resource "aws_iam_role_policy_attachment" "ecs_alb_service_role_policy" {
  role       = aws_iam_role.ecs_alb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}