###############################################
# VPC
###############################################
resource "aws_vpc" "vpc" {
  cidr_block                       = "192.168.0.0/20"
  instance_tenancy                 = "default" #基本はデフォルトでよい
  enable_dns_support               = true      #DNS解決
  enable_dns_hostnames             = true      #DNSホスト名
  assign_generated_ipv6_cidr_block = false     #IPv6

  tags = {
    Name    = "${var.project}-${var.environment}-vpc"
    Project = var.project
    Env     = var.environment
  }
}

###############################################
# Subnet (availability zone: ap-northeast-1a)
###############################################

# インバウンド通信用のパブリックサブネット
resource "aws_subnet" "public_subnet_ingress" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project}-${var.environment}-public-subnet-ingress"
    Project = var.project
    Env     = var.environment
  }
}

# 開発環境配置用のパブリックサブネット
resource "aws_subnet" "public_subnet_mgmt" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project}-${var.environment}-public-subnet-mgmt"
    Project = var.project
    Env     = var.environment
  }
}

# アプリケーション配置用のプライベートサブネット
resource "aws_subnet" "private_subnet_app" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.3.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-app"
    Project = var.project
    Env     = var.environment
  }
}

# データベース配置用のプライベートサブネット
resource "aws_subnet" "private_subnet_db" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.4.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-db"
    Project = var.project
    Env     = var.environment
  }
}

# アウトバウンド通信用のプライベートサブネット
resource "aws_subnet" "private_subnet_egress" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.5.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-egress"
    Project = var.project
    Env     = var.environment
  }
}

###############################################
# # Subnet (availability zone: ap-northeast-1c)
###############################################

# インバウンド通信用のパブリックサブネット
resource "aws_subnet" "public_subnet_ingress-1c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.6.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project}-${var.environment}-public-subnet-ingress-1c"
    Project = var.project
    Env     = var.environment
  }
}

# 開発環境配置用のパブリックサブネット
resource "aws_subnet" "public_subnet_mgmt-1c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.7.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project}-${var.environment}-public-subnet-mgmt-1c"
    Project = var.project
    Env     = var.environment
  }
}

# アプリケーション配置用のプライベートサブネット
resource "aws_subnet" "private_subnet_app-1c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.8.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-app-1c"
    Project = var.project
    Env     = var.environment
  }
}

# データベース配置用のプライベートサブネット
resource "aws_subnet" "private_subnet_db-1c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.9.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-db-1c"
    Project = var.project
    Env     = var.environment
  }
}

# アウトバウンド通信用のプライベートサブネット
resource "aws_subnet" "private_subnet_egress-1c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.10.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-egress-1c"
    Project = var.project
    Env     = var.environment
  }
}

###############################################
# Internet Gateway
###############################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.environment}-igw"
    Project = var.project
    Env     = var.environment
  }
}

###############################################
# Route Table
###############################################

# パブリックサブネット(ingress)用のルートテーブル
resource "aws_route_table" "public_route_table_ingress" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project}-${var.environment}-public-route-table-ingress"
    Project = var.project
    Env     = var.environment
  }
}

resource "aws_route_table_association" "public_ingress" {
  subnet_id      = aws_subnet.public_subnet_ingress.id
  route_table_id = aws_route_table.public_route_table_ingress.id
}


# パブリックサブネット(mgmt)用のルートテーブル
resource "aws_route_table" "public_route_table_mgmt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project}-${var.environment}-public-route-table-mgmt"
    Project = var.project
    Env     = var.environment
  }
}

resource "aws_route_table_association" "public_mgmt" {
  subnet_id      = aws_subnet.public_subnet_mgmt.id
  route_table_id = aws_route_table.public_route_table_mgmt.id
}


# プライベートサブネット(app)用のルートテーブル
resource "aws_route_table" "private_route_table_app" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.environment}-private-route-table-app"
    Project = var.project
    Env     = var.environment
  }
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = aws_subnet.private_subnet_app.id
  route_table_id = aws_route_table.private_route_table_app.id
}
resource "aws_vpc_endpoint_route_table_association" "private_app_s3" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id                    # S3エンドポイントのID (vpce-...)
  route_table_id  = aws_route_table.private_route_table_app.id # 紐付けたいルートテーブルのID (rtb-...)
}

# プライベートサブネット(db)用のルートテーブル
resource "aws_route_table" "private_route_table_db" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.environment}-private-route-table-db"
    Project = var.project
    Env     = var.environment
  }
}

resource "aws_route_table_association" "private_db" {
  subnet_id      = aws_subnet.private_subnet_db.id
  route_table_id = aws_route_table.private_route_table_db.id
}

# プライベートサブネット(egress)用のルートテーブル
resource "aws_route_table" "private_route_table_egress" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.environment}-private-route-table-egress"
    Project = var.project
    Env     = var.environment
  }
}

resource "aws_route_table_association" "private_egress" {
  subnet_id      = aws_subnet.private_subnet_egress.id
  route_table_id = aws_route_table.private_route_table_egress.id
}

###############################################
# Route Table 1c
###############################################

# パブリックサブネット(ingress)用のルートテーブル
resource "aws_route_table" "public_route_table_ingress-1c" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project}-${var.environment}-public-route-table-ingress-1c"
    Project = var.project
    Env     = var.environment
  }
}

resource "aws_route_table_association" "public_ingress-1c" {
  subnet_id      = aws_subnet.public_subnet_ingress-1c.id
  route_table_id = aws_route_table.public_route_table_ingress-1c.id
}

# プライベートサブネット(app)用のルートテーブル
resource "aws_route_table" "private_route_table_app-1c" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.environment}-private-route-table-app-1c"
    Project = var.project
    Env     = var.environment
  }
}

resource "aws_route_table_association" "private_app-1c" {
  subnet_id      = aws_subnet.private_subnet_app-1c.id
  route_table_id = aws_route_table.private_route_table_app-1c.id
}
resource "aws_vpc_endpoint_route_table_association" "private_app_s3-1c" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id                   
  route_table_id = aws_route_table.private_route_table_app-1c.id
}
# プライベートサブネット(db)用のルートテーブル
resource "aws_route_table" "private_route_table_db-1c" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.environment}-private-route-table-db-1c"
    Project = var.project
    Env     = var.environment
  }
}

resource "aws_route_table_association" "private_db-1c" {
  subnet_id      = aws_subnet.private_subnet_db-1c.id
  route_table_id = aws_route_table.private_route_table_db-1c.id
}

# プライベートサブネット(egress)用のルートテーブル
resource "aws_route_table" "private_route_table_egress-1c" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.environment}-private-route-table-egress-1c"
    Project = var.project
    Env     = var.environment
  }
}
resource "aws_route_table_association" "private_egress-1c" {
  subnet_id      = aws_subnet.private_subnet_egress-1c.id
  route_table_id = aws_route_table.private_route_table_egress-1c.id
}

###############################################
# Security Group
###############################################

# ALB用のセキュリティグループ　
resource "aws_security_group" "alb_sg" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-${var.environment}-alb-sg"
    Project = var.project
    Env     = var.environment
  }
}

# 開発端末インスタンスのセキュリティグループ
resource "aws_security_group" "mgmt_sg" {
  name        = "${var.project}-${var.environment}-mgmt-sg"
  description = "Security group for mgmt instances"
  vpc_id      = aws_vpc.vpc.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RDP
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-${var.environment}-mgmt-sg"
    Project = var.project
    Env     = var.environment
  }
}

# Fargate（フロントエンド）のセキュリティグループ
resource "aws_security_group" "fargate_frontend_sg" {
  name        = "${var.project}-${var.environment}-fargate-frontend-sg"
  description = "Security group for Frontend Fargate containers"
  vpc_id      = aws_vpc.vpc.id

  # ALBからのリクエスト
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-${var.environment}-fargate-frontend-sg"
    Project = var.project
    Env     = var.environment
  }
}

# Fargate（バックエンド）のセキュリティグループ
resource "aws_security_group" "fargate_backend_sg" {
  name        = "${var.project}-${var.environment}-fargate-backend-sg"
  description = "Security group for Backend Fargate containers"
  vpc_id      = aws_vpc.vpc.id

  # フロントエンドからのリクエスト
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-${var.environment}-fargate-backend-sg"
    Project = var.project
    Env     = var.environment
  }
}

# AuroraDBのセキュリティグループ
resource "aws_security_group" "aurora_sg" {
  name        = "${var.project}-${var.environment}-aurora-sg"
  description = "Security group for Aurora DB"
  vpc_id      = aws_vpc.vpc.id

  # バックエンドからのリクエスト
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-${var.environment}-aurora-sg"
    Project = var.project
    Env     = var.environment
  }
}

# VPCエンドポイント（インターフェイス型だからENIがつくられるため）のセキュリティグループ
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${var.project}-${var.environment}-vpc-endpoint-sg"
  description = "Security group for VPC Endpoints"
  vpc_id      = aws_vpc.vpc.id

  # アプリケーションサブネット内のリソースからのリクエストのみ許可する
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [
      aws_security_group.fargate_frontend_sg.id, #ここも追加。VPCエンドポイントを通してECRにアクセスするため、フロントエンドのFargateからのアクセスも許可する必要がある
      aws_security_group.fargate_backend_sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-${var.environment}-vpc-endpoint-sg"
    Project = var.project
    Env     = var.environment
  }
}

###############################################
# VPCエンドポイント（ゲートウェイ型）
###############################################

# VPCエンドポイント（S3用）
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Name    = "${var.project}-${var.environment}-vpc-endpoint-s3"
    Project = var.project
    Env     = var.environment
  }
}

###############################################
# VPCエンドポイント（インターフェイス型）
###############################################

# VPCエンドポイント（ECR API用）
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.ap-northeast-1.ecr.api"
  vpc_endpoint_type = "Interface"
  security_group_ids = [
    aws_security_group.vpc_endpoint_sg.id
  ]
  subnet_ids = [
    aws_subnet.private_subnet_egress.id
  ]

  private_dns_enabled = true

  tags = {
    Name    = "${var.project}-${var.environment}-vpc-endpoint-ecr-api"
    Project = var.project
    Env     = var.environment
  }
}

# VPCエンドポイント（ECR DKR用）
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.ap-northeast-1.ecr.dkr"
  vpc_endpoint_type = "Interface"
  security_group_ids = [
    aws_security_group.vpc_endpoint_sg.id
  ]
  subnet_ids = [
    aws_subnet.private_subnet_egress.id
  ]

  private_dns_enabled = true

  tags = {
    Name    = "${var.project}-${var.environment}-vpc-endpoint-ecr-dkr"
    Project = var.project
    Env     = var.environment
  }
}