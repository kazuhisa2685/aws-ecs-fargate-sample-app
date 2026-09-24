resource "aws_sns_topic" "sns_sendmsg" {
  name = "${var.project}-${var.environment}-sns-sendmsg"
}

resource "aws_sns_topic_subscription" "sns_subscription_sendmsg" {
  topic_arn = aws_sns_topic.sendmsg.arn
  protocol  = "lambda"
  endpoint  = var.sendmsg_arn
}