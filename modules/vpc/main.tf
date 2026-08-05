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