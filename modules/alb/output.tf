output "tg_blue_arn" {
  value = aws_lb_target_group.tg_blue.arn
}
output "tg_green_arn" {
  value = aws_lb_target_group.tg_green.arn
}
output "aws_lb_listener_production_listener" {
  value = aws_lb_listener.production_listener
}
output "aws_lb_listener_test_listener" {
  value = aws_lb_listener.test_listener
}

output "aws_lb_listener_rule_production_rule" {
  value = aws_lb_listener_rule.production_rule
}
output "aws_lb_listener_rule_test_rule" {
  value = aws_lb_listener_rule.test_rule
}