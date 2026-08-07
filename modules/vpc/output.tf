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