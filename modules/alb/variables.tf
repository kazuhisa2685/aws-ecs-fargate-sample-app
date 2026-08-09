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
variable "public_subnet_ingress_id" {
  type = string
}
variable "public_subnet_ingress_id-1c" {
  type = string
}
variable "alb_sg_id" {
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

variable "ecs_cluster_id" {
  type = string
}
