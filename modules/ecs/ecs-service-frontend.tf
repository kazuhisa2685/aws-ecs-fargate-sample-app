# ################################################
# # ECS サービス用
# ################################################
resource "aws_ecs_service" "ecs_frontend_service" {
  name            = "${var.project}-${var.environment}-frontend-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_frontend_taskdef.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  #enable_execute_command = true 
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn
  }
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
    target_group_arn = var.frontend_target_group_1_arn
    container_name   = "app"
    container_port   = 1500
    advanced_configuration {
      alternate_target_group_arn = var.frontend_target_group_2_arn
      production_listener_rule   = var.frontend_production_listener_rule_arn
      test_listener_rule         = var.frontend_test_listener_rule_arn
      role_arn                   = var.ecs_infrastructure_role_for_load_balancers_arn
    }
  }
  network_configuration {
    subnets          = [var.private_subnet_id, var.private_subnet_id-1c]
    security_groups  = [var.fargate_frontend_sg_id]
    assign_public_ip = false
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
  #depends_on = [aws_lb_target_group.tg_blue]
}