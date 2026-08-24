####################################################
# Terraform configuration
####################################################
terraform {
  required_version = ">=1.10" #use_lockfile はTerraform 1.10以降の機能のため
  required_providers {
    aws = {
      source = "hashicorp/aws"
      #AWSプロバイダーバージョン設定（terraformのバージョンではない）
      #GitHub Actionsのプロバイダーも　initの際に -updateオプションを使うとプロバイダー更新できる
      version = "~> 6.0"
    }
  }

  # tfstateを管理するためのバックエンドS3を認識する。
  backend "s3" {
    bucket       = "dev-portfolio-tfstate-bucket" # リリース対象とは別のアカウントのS3バケットに保存することが推奨される
    key          = "dev.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}

####################################################
# Provider
####################################################
provider "aws" {
  # profile はローカル専用の設定であり、CI環境にはそのプロファイルが存在しないので、コメントアウト。
  # profile = "terraform"
  region = "ap-northeast-1"
}

####################################################
# 共通変数
####################################################
locals {
  project     = "sample"
  environment = "dev"
}

####################################################
# module モジュールを呼び出す
# ユースケース：引数の値を指定する
# 　　　　　　　sourceでどのモジュールを呼び出すかを指定する
####################################################

module "vpc" {
  source      = "../../modules/vpc"
  project     = local.project
  environment = local.environment
}

# module "ec2" {
#   source               = "../../modules/ec2"
#   project              = local.project
#   environment          = local.environment
#   subnet_id            = module.vpc.public_subnet_mgmt_id
#   iam_instance_profile = module.iam.iam_instance_profile.name
#   mgmt_sg_id           = module.vpc.mgmt_sg_id
# }

module "iam" {
  source      = "../../modules/iam"
  project     = local.project
  environment = local.environment
}

# module "ecr" {
#   source      = "../../modules/ecr"
#   project     = local.project
#   environment = local.environment
# }

module "ecs" {
  source                                         = "../../modules/ecs"
  project                                        = local.project
  environment                                    = local.environment
  private_subnet_id                              = module.vpc.private_subnet_app_id
  private_subnet_id-1c                           = module.vpc.private_subnet_app_id-1c
  fargate_frontend_sg_id                         = module.vpc.fargate_frontend_sg_id
  aws_lb_target_group_target_1_arn               = module.alb.aws_lb_target_group_target_1.arn
  aws_lb_target_group_target_2_arn               = module.alb.aws_lb_target_group_target_2.arn
  aws_lb_listener_rule_production_rule_arn       = module.alb.aws_lb_listener_rule_production_rule.arn
  aws_lb_listener_rule_test_rule_arn             = module.alb.aws_lb_listener_rule_test_rule.arn
  ecs_task_execution_role_arn                    = module.iam.ecs_task_execution_role_arn
  ecs_infrastructure_role_for_load_balancers_arn = module.iam.ecs_infrastructure_role_for_load_balancers_arn
}

module "alb" {
  source                      = "../../modules/alb"
  project                     = local.project
  environment                 = local.environment
  public_subnet_ingress_id    = module.vpc.public_subnet_ingress_id
  public_subnet_ingress_id-1c = module.vpc.public_subnet_ingress_id-1c
  alb_sg_id                   = module.vpc.alb_sg_id
  vpc_id                      = module.vpc.vpc_id
  private_subnet_id           = module.vpc.private_subnet_app_id
  private_subnet_id-1c        = module.vpc.private_subnet_app_id-1c
  fargate_frontend_sg_id      = module.vpc.fargate_frontend_sg_id
  ecs_cluster_id              = module.ecs.ecs_cluster_id
}