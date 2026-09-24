resource "aws_sns_topic" "example" {
  name = "${var.project}-${var.environment}-sns-sendmsg"
}