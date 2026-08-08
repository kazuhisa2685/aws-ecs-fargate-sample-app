####################################################
# output モジュールの出力結果を取り出す
# ユースケース：他の Terraform モジュールやステージへの値の受け渡し
# 　　　　　　　CI/CD や外部スクリプトへの値の引き渡し
####################################################
output "vpc_id" {
  value = aws_vpc.vpc.id
}
output "public_subnet_mgmt_id" {
  value = aws_subnet.public_subnet_mgmt.id
}

output "vpc_endpoint_sg_id" {
  value = aws_security_group.vpc_endpoint_sg.id
}

output "mgmt_sg_id" {
  value = aws_security_group.mgmt_sg.id
}

output "public_subnet_app_id" {
  value = aws_subnet.public_subnet_ingress.id
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

#############################################
# availability_zone 1c
#############################################

output "public_subnet_app_id-1c" {
  value = aws_subnet.public_subnet_ingress-1c.id
}