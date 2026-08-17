###############################################
# ECS クラスター (ECS更新時、ヘルスチェック猶予期間を設定することを忘れずに)
###############################################
resource "aws_ecs_cluster" "ecs_frontend_cluster" {
  name = "${var.project}-${var.environment}-cluster"
  setting {
    name  = "containerInsights"
    value = "enhanced"
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

# ################################################
# # ECS サービス用
# ################################################
resource "aws_ecs_service" "ecs_frontend_service" {
  name            = "${var.project}-${var.environment}-service"
  cluster         = aws_ecs_cluster.ecs_frontend_cluster.id
  task_definition = aws_ecs_task_definition.ecs_frontend_taskdef.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  deployment_configuration {
    strategy             = "BLUE_GREEN"
    bake_time_in_minutes = 1            # 新バージョン(Green)へ切り替えた後、旧タスク(Blue)を削除するまでの待機時間（分）
  }
  load_balancer {
    container_name = "app"
    container_port = 8080
    target_group_arn = var.tg_blue_arn
    advanced_configuration {
      alternate_target_group_arn = var.tg_green_arn
      production_listener_rule   = var.production_listener_rule_arn
      # test_listener_rule          = "${var.test_listener_rule_arn}"            # テストトラフィック用（オプション）
      role_arn = var.ecs_infrastructure_role_for_load_balancers_arn
    }
  }
  network_configuration {
    subnets         = [var.private_subnet_id, var.private_subnet_id-1c]
    security_groups = [var.fargate_frontend_sg_id]
  }
  lifecycle {
    ignore_changes = [
      load_balancer,
      task_definition,
    ]
  }
  #depends_on = [aws_lb_target_group.tg_blue]
}