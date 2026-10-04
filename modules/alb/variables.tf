# ---------------------------------------------
# Variables
# ---------------------------------------------
variable "project" {
  type = string
}
variable "environment" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "public_subnet_ingress_ids" {
  type = list(string)
}
variable "alb_sg_id" {
  type = string
}
variable "fargate_frontend_sg_id" {
  type = string
}

variable "ecs_cluster_id" {
  type = string
}
