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
variable "fargate_backend_sg_id" {
  type = string
}

variable "ecs_task_execution_role_arn" {
  type = string
}
variable "ecs_infrastructure_role_for_load_balancers_arn" {
  type = string
}

# ============================
# Frontend
# ============================

variable "frontend_target_group_1_arn" {
  type        = string
  description = "Frontend Blue target group ARN"
}

variable "frontend_target_group_2_arn" {
  type        = string
  description = "Frontend Green target group ARN"
}

variable "frontend_production_listener_rule_arn" {
  type        = string
  description = "Frontend production listener rule ARN"
}

variable "frontend_test_listener_rule_arn" {
  type        = string
  description = "Frontend test listener rule ARN"
}

# ============================
# Backend
# ============================

variable "backend_target_group_1_arn" {
  type        = string
  description = "Backend Blue target group ARN"
}

variable "backend_target_group_2_arn" {
  type        = string
  description = "Backend Green target group ARN"
}

variable "backend_production_listener_rule_arn" {
  type        = string
  description = "Backend production listener rule ARN"
}

variable "backend_test_listener_rule_arn" {
  type        = string
  description = "Backend test listener rule ARN"
}
###############################################
# image tags
################################################
variable "frontend_image_tag" {
  type        = string
  description = "Frontend Docker Image Tag"
  # default     = "latest"
}
variable "backend_image_tag" {
  type        = string
  description = "Backend Docker Image Tag"
  # default     = "latest"
}