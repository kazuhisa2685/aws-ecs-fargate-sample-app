###############################################
# ECR リポジトリ
###############################################

# ecrフロントエンドリポジトリ
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project}-${var.environment}-frontend"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true #ベーシックスキャンで無料なので、一応入れとく。もっと高度なスキャン（拡張スキャン）は有料なので、必要に応じて検討する。
  }
}

# ecrバックエンドリポジトリ
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project}-${var.environment}-backend"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true #ベーシックスキャンで無料なので、一応入れとく。もっと高度なスキャン（拡張スキャン）は有料なので、必要に応じて検討する。
  }
}