###############################################
# 開発端末
###############################################

# 開発端末用EC2インスタンス
resource "aws_instance" "dev_instance" {
  ami           = "ami-0126975fb247bf2e7"
  instance_type = "t3.large"
  subnet_id     = "${var.subnet_id}"

  tags = {
    Name    = "${var.project}-${var.environment}-dev-instance"
    Project = var.project
    Env     = var.environment
  }
}