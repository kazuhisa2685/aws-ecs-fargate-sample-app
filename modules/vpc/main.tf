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
# Subnet
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
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.3.0/24"
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-app"
    Project = var.project
    Env     = var.environment
  }
}

# データベース配置用のプライベートサブネット
resource "aws_subnet" "private_subnet_db" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.4.0/24"
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-db"
    Project = var.project
    Env     = var.environment
  }
}

# アウトバウンド通信用のプライベートサブネット
resource "aws_subnet" "private_subnet_egress" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.5.0/24"
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name    = "${var.project}-${var.environment}-private-subnet-egress"
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
