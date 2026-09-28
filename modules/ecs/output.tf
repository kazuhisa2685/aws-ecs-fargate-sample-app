output "ecs_cluster_id" {
  value = aws_ecs_cluster.ecs_cluster.id
}

output "ecs_frontend_log_group_name" {
  value = aws_cloudwatch_log_group.ecs_frontend_log_group.name
}

output "ecs_backend_log_group_name" {
  value = aws_cloudwatch_log_group.ecs_backend_log_group.name
}