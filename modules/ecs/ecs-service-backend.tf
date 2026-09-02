# ################################################
# # ECS サービス用
# ################################################
resource "aws_ecs_service" "ecs_backend_service" {
  name            = "${var.project}-${var.environment}-backend-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_backend_taskdef.arn
  desired_count   = 2
  launch_type     = "FARGATE"

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
  lifecycle {
    ignore_changes = [task_definition]
  }
  #depends_on = [aws_lb_target_group.tg_blue]
}