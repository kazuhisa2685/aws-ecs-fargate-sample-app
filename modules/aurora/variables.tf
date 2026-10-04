# ---------------------------------------------
# Variables
# ---------------------------------------------
variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_db_ids" {
  type        = list(string)
  description = "Database private subnet IDs"
}
variable "aws_security_group_aurora_sg_id" {
  type = string
}


