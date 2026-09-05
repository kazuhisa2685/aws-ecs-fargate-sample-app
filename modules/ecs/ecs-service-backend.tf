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
    bake_time_in_minutes = 1
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
    subnets          = [var.private_subnet_id, var.private_subnet_id-1c]
    security_groups  = [var.fargate_backend_sg_id]
    assign_public_ip = false
  }

  depends_on = [
    aws_ecs_task_definition.ecs_backend_taskdef
  ]
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      discovery_name    = "backend-service" # ← ほかのコンテナから見上げる時のホスト名になる
      port_name         = "backend-port"     # ← タスク定義の portMappings.name と一致させる必要がある
      client_alias {
        port = 8000
        dns_name = "backend-service"
      }
    }
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
  #depends_on = [aws_lb_target_group.tg_blue]
}