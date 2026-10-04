variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "iam_instance_profile" {
  type = string
}

variable "mgmt_sg_id" {
  type = string
}
