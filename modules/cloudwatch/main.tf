resource "aws_cloudwatch_metric_filter" "frontend_metric_filter" {
  name           = "${var.project}-${var.environment}-frontend-metric_filter"
  log_group_name = var.ecs_frontend_log_group_name
  pattern        = "{ $.statusCode = 200 }"

  metric_transformation {
    name      = "HTTP200Count"
    namespace = "${var.project}/${var.environment}/Frontend"
    value     = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_filter" "backend_metric_filter" {
  name           = "${var.project}-${var.environment}-frontend-metric_filter"
  log_group_name = var.ecs_backend_log_group_name
  pattern        = "{ $.statusCode = 200 }"

  metric_transformation {
    name      = "HTTP200Count"
    namespace = "${var.project}/${var.environment}/backend"
    value     = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_metric_alarm" {
  alarm_name          = "${var.project}-${var.environment}-frontend-2xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"  # 閾値以上になったら
  evaluation_periods  = 1                                # 判定を行う評価期間の数（例: 1回）
  metric_name         = aws_cloudwatch_metric_filter.frontend_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_metric_filter.frontend_metric_filter.metric_transformation[0].namespace
  period              = 60                               # 集計期間（秒）: 1分間
  statistic           = "Sum"                            # 集計方法: 合計値
  threshold           = 1                                # 閾値: 1回以上発生したら

  alarm_description   = "Frontend 200 detected in logs."
  treat_missing_data  = "notBreaching"                   # データがない時は「正常」とみなす

  # alarm_actions     = [aws_sns_topic.log_alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "backend_metric_alarm" {
  alarm_name          = "${var.project}-${var.environment}-backend-2xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"  # 閾値以上になったら
  evaluation_periods  = 1                                # 判定を行う評価期間の数（例: 1回）
  metric_name         = aws_cloudwatch_metric_filter.backend_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_metric_filter.backend_metric_filter.metric_transformation[0].namespace
  period              = 60                               # 集計期間（秒）: 1分間
  statistic           = "Sum"                            # 集計方法: 合計値
  threshold           = 1                                # 閾値: 1回以上発生したら

  alarm_description   = "Frontend 200 detected in logs."
  treat_missing_data  = "notBreaching"                   # データがない時は「正常」とみなす

  # alarm_actions     = [aws_sns_topic.log_alarm.arn]
}