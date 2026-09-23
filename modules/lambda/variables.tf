variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "call_devops_agent_name" {
  description = "Name of the CallDevopsAgent Lambda function"
  type        = string
}

variable "send_msg_name" {
  description = "Name of the SendMsg Lambda function"
  type        = string
}

variable "call_devops_agent_role_arn" {
  description = "ARN of the CallDevopsAgent role"
  type        = string
}

variable "send_msg_role_arn" {
  description = "ARN of the SendMsg role"
  type        = string
}