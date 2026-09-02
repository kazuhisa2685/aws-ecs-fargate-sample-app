output "aws_lb_target_group_frontend_target_1" {
  value = aws_lb_target_group.frontend_target_1
}
output "aws_lb_target_group_frontend_target_2" {
  value = aws_lb_target_group.frontend_target_2
}
output "aws_lb_listener_frontend_production_listener" {
  value = aws_lb_listener.frontend_production_listener
}
output "aws_lb_listener_rule_frontend_production_listener_rule" {
  value = aws_lb_listener_rule.frontend_production_listener_rule
}
output "aws_lb_listener_frontend_test_listener" {
  value = aws_lb_listener.frontend_test_listener
}
output "aws_lb_listener_rule_frontend_test_listener_rule" {
  value = aws_lb_listener_rule.frontend_test_listener_rule
}

output "aws_lb_target_group_backend_target_1" {
  value = aws_lb_target_group.backend_target_1
}
output "aws_lb_target_group_backend_target_2" {
  value = aws_lb_target_group.backend_target_2
}
output "aws_lb_listener_backend_production_listener" {
  value = aws_lb_listener.backend_production_listener
}
output "aws_lb_listener_rule_backend_production_listener_rule" {
  value = aws_lb_listener_rule.backend_production_listener_rule
}
output "aws_lb_listener_backend_test_listener" {
  value = aws_lb_listener.backend_test_listener
}
output "aws_lb_listener_rule_backend_test_listener_rule" {
  value = aws_lb_listener_rule.backend_test_listener_rule
}