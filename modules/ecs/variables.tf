# ---------------------------------------------
# Variables
# ---------------------------------------------
variable "project" {
  type = string
}
variable "environment" {
  type = string
}
variable "private_subnet_id" {
  type = string
}
variable "private_subnet_id-1c" {
  type = string
}

variable "fargate_frontend_sg_id" {
  type = string
}
variable "tg_green_arn" {
  type = string
}
variable "tg_blue_arn" {
  type = string
}
variable "alb_listener_arn" {
  type = string
}
variable "production_listener_rule_arn" {
  type = string
}
