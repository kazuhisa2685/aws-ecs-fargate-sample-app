####################################################
# output モジュールの出力結果を取り出す
# ユースケース：他の Terraform モジュールやステージへの値の受け渡し
# 　　　　　　　CI/CD や外部スクリプトへの値の引き渡し
####################################################

output "iam_instance_profile" {
  value = aws_iam_instance_profile.ssm_profile
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}
output "ecs_infrastructure_role_for_load_balancers_arn" {
  value = aws_iam_role.ecs_infrastructure_role_for_load_balancers.arn
}