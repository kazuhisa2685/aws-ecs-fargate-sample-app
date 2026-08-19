output "tg_blue_arn" {
  value = aws_lb_target_group.tg_blue.arn
}
output "tg_green_arn" {
  value = aws_lb_target_group.tg_green.arn
}
output "alb_listener_arn" {
  value = aws_lb_listener.http.arn
}
output "alb_listener_rule_prod_arn" {
  value = aws_lb_listener_rule.prod.arn
}