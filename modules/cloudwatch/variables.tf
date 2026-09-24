variable "project" {
  type = string
}
variable "environment" {
  type = string
}

variable "ecs_frontend_log_group_name" {
  type = string
}

variable "ecs_backend_log_group_name" {
  type = string
}
variable "sns_sendmsg_arn" {
  type = string
}