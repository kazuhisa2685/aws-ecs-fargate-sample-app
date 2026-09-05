###############################################
# ECR リポジトリ
###############################################

# ecrフロントエンドリポジトリ
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project}-${var.environment}-frontend"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = false
  }
}

# ecrバックエンドリポジトリ
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project}-${var.environment}-backend"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = false
  }
}