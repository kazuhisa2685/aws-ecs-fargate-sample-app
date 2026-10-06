# ################################################
# # ECS サービス用
# ################################################
resource "aws_ecs_service" "ecs_backend_service" {
  name            = "${var.project}-${var.environment}-backend-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_backend_taskdef.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  #enable_execute_command = true 

  # ECS標準型BlueGreen
  deployment_controller {
    type = "ECS"
  }
  deployment_configuration {
    strategy             = "BLUE_GREEN"
    bake_time_in_minutes = 5
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  load_balancer {
    target_group_arn = var.backend_target_group_1_arn
    container_name   = "main"
    container_port   = 8000
    advanced_configuration {
      alternate_target_group_arn = var.backend_target_group_2_arn
      production_listener_rule   = var.backend_production_listener_rule_arn
      test_listener_rule         = var.backend_test_listener_rule_arn
      role_arn                   = var.ecs_infrastructure_role_for_load_balancers_arn
    }
  }
  network_configuration {
    subnets          = var.private_subnet_app_ids
    security_groups  = [var.fargate_backend_sg_id]
    assign_public_ip = false
  }

  # depends_on = [
  #   aws_ecs_task_definition.ecs_backend_taskdef
  # ]
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      discovery_name = "backend-service" # ← ほかのコンテナから見上げる時のホスト名になる
      port_name      = "backend-port"    # ← タスク定義の portMappings.name と一致させる必要がある
      client_alias {
        port     = 8000
        dns_name = "backend-service"
      }
    }
  }
  lifecycle {
    ignore_changes = [
      task_definition, #Terraform管理外でECSサービスのTask Definitionが更新されても、Terraform planで差分として扱わない
      desired_count # ECS Service側で変更されるdesired_countをTerraformの差分検出から除外 オートスケーリングでdesired_countが変化してもTerraform planで差分として扱わないための設定　これで、スケーリングしても元のdesired_countに戻されることを防ぐ
    ]
  }
  #depends_on = [aws_lb_target_group.tg_blue]
}
resource "aws_appautoscaling_target" "ecs_backend_autoscaling_target" {
  max_capacity       = 10
  min_capacity       = 2 # 昼間の基本最小数
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_backend_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

#ターゲットスケーリングにより、トラフィックの予測が難しいシステムでも、CPU使用率を一定に保つように自動でスケーリングすることが可能
resource "aws_appautoscaling_policy" "ecs_backend_targetscaling_policy" {
  name               = "${var.project}-${var.environment}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_backend_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_backend_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_backend_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0 # CPU使用率70%を維持するように自動調整
    scale_in_cooldown  = 300  # スケールイン後のクールダウン時間(秒)
    scale_out_cooldown = 60   # スケールアウト後のクールダウン時間(秒)
  }
}

# 夜間（例: JST 22:00 -> UTC 13:00）に最小キャパシティを縮退させる設定
resource "aws_appautoscaling_scheduled_action" "ecs_backend_scale_down_night" {
  name               = "${var.project}-${var.environment}-scale-down-night"
  resource_id        = aws_appautoscaling_target.ecs_backend_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_backend_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_backend_autoscaling_target.service_namespace
  
  # UTC時間で指定 (cron(分 時 日 月 曜日 年))
  # 毎日 UTC 13:00 (JST 22:00) に min_capacity を 1 に変更
  schedule = "cron(0 13 * * ? *)"

  scalable_target_action {
    min_capacity = 1
    max_capacity = 5
  }
}

# 朝（例: JST 08:00 -> UTC 23:00 前日）に最小キャパシティを復元させる設定
resource "aws_appautoscaling_scheduled_action" "ecs_backend_scale_up_morning" {
  name               = "${var.project}-${var.environment}-scale-up-morning"
  resource_id        = aws_appautoscaling_target.ecs_backend_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_backend_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_backend_autoscaling_target.service_namespace
  
  # 毎日 UTC 23:00 (JST 08:00) に min_capacity を 2 に戻す
  schedule = "cron(0 23 * * ? *)"

  scalable_target_action {
    min_capacity = 2
    max_capacity = 10
  }
}