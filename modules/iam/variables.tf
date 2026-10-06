# ---------------------------------------------
# Variables
# ---------------------------------------------
variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "function_name" {
  type = string
}

variable "aws_rds_cluster_aurora_cluster_master_user_secret_arn" {
  type = string
}