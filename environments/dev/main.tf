####################################################
# Terraform configuration
####################################################
terraform {
  required_version = ">=0.13"
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