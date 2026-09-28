output "function_name" {
  value = aws_lambda_function.CallDevopsAgent.function_name
}

output "sendmsg_arn" {
  value = aws_lambda_function.SendMsg.arn
}