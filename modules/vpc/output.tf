####################################################
# output モジュールの出力結果を取り出す
# ユースケース：他の Terraform モジュールやステージへの値の受け渡し
# 　　　　　　　CI/CD や外部スクリプトへの値の引き渡し
####################################################
output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ingress_ids" {
  value = [for s in aws_subnet.public_subnet_ingress : s.id]
}

output "public_subnet_mgmt_ids" {
  value = [for s in aws_subnet.public_subnet_mgmt : s.id]
}

output "private_subnet_app_ids" {
  value = [for s in aws_subnet.private_subnet_app : s.id]
}

output "private_subnet_db_ids" {
  value = [for s in aws_subnet.private_subnet_db : s.id]
}

output "private_subnet_egress_ids" {
  value = [for s in aws_subnet.private_subnet_egress : s.id]
}


output "vpc_endpoint_sg_id" {
  value = aws_security_group.vpc_endpoint_sg.id
}

output "mgmt_sg_id" {
  value = aws_security_group.mgmt_sg.id
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "fargate_frontend_sg_id" {
  value = aws_security_group.fargate_frontend_sg.id
}

output "fargate_backend_sg_id" {
  value = aws_security_group.fargate_backend_sg.id
}

output "aws_security_group_aurora_sg_id" {
  value = aws_security_group.aurora_sg.id
}