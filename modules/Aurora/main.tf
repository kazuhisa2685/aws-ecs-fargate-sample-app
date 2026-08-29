###############################################
# Aurora
###############################################

# Auroraサブネットグループ構築
resource "aws_db_subnet_group" "aurora" {
  name        = "${var.project}-${var.environment}-aurora-subnet-group"
  description = "Aurora DB subnet group"

  subnet_ids = [
    var.private_subnet_app_db_id,
    var.private_subnet_app_db_id-1c,
  ]

  tags = {
    Name        = "${var.project}-${var.environment}-aurora-subnet-group"
    Project     = var.project
    Environment = var.environment
  }
}

# Auroraクラスター
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier  = "${var.project}-${var.environment}-cluster"
  engine              = "aurora-postgresql"
  engine_mode         = "provisioned"
  master_username     = "adminuser"
  skip_final_snapshot = true #検証用のため

  # Secrets Managerで管理させる設定
  manage_master_user_password = true

  # ネットワーク関連
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [var.aws_security_group_aurora_sg_id]

  # Serverless v2 のスケーリング設定
  serverlessv2_scaling_configuration {
    min_capacity = 0 #非アクティブ時に一時停止
    max_capacity = 4
  }

  storage_encrypted       = true
  backup_retention_period = 7
}

#インスタンス
resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = 1
  identifier         = "my-aurora-dev-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id

  instance_class     = "db.t4g.medium"
  engine             = aws_rds_cluster.aurora_cluster.engine

  # publicアクセス禁止
  publicly_accessible = false
}