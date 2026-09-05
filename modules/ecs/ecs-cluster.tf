###############################################
# ECS クラスター (ECS更新時、ヘルスチェック猶予期間を設定することを忘れずに)
###############################################
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.project}-${var.environment}-cluster"
  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.main.arn
  }
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
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 1
    capacity_provider = "FARGATE"
  }
}

#サービスコネクト
resource "aws_service_discovery_http_namespace" "main" {
  name = "${var.project}-${var.environment}-namespace"
  description = "Service Discovery Namespace for ${var.project}-${var.environment}"
}