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

variable "ecs_task_execution_role_arn" {
  type = string
}
variable "ecs_infrastructure_role_for_load_balancers_arn" {
  type = string
}
variable "aws_lb_listener_rule_production_rule_arn" {
  type = string
}
variable "aws_lb_listener_rule_test_rule_arn" {
  type = string
}