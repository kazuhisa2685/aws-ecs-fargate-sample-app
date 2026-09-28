# ==============================================================================
# ========== BACKEND ==========
# ==============================================================================

# ------------------------------------------------------------------------------
# [Backend] 3xx メトリクスフィルター
# アクセスログから 3xx 系エラーレスポンスをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "backend_3xx_metric_filter" {
  name           = "${var.project}-${var.environment}-backend-3xx-metric-filter"
  log_group_name = var.ecs_backend_log_group_name
  pattern        = "[ip, id, user, timestamp, request, status_code=3*, size]"

  metric_transformation {
    name          = "Backend3xxCount"
    namespace     = "${var.project}/${var.environment}/Backend"
    value         = "1"
    default_value = "0"
  }
}

# [Backend] 3xx アラーム — 3xx エラーを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "backend_3xx_alarm" {
  alarm_name          = "${var.project}-${var.environment}-backend-3xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.backend_3xx_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.backend_3xx_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Backend 3xx error detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}
# ------------------------------------------------------------------------------
# [Backend] 4xx メトリクスフィルター
# アクセスログから 4xx 系エラーレスポンスをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "backend_4xx_metric_filter" {
  name           = "${var.project}-${var.environment}-backend-4xx-metric-filter"
  log_group_name = var.ecs_backend_log_group_name
  pattern        = "[ip, id, user, timestamp, request, status_code=4*, size]"

  metric_transformation {
    name          = "Backend4xxCount"
    namespace     = "${var.project}/${var.environment}/Backend"
    value         = "1"
    default_value = "0"
  }
}

# [Backend] 4xx アラーム — 4xx エラーを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "backend_4xx_alarm" {
  alarm_name          = "${var.project}-${var.environment}-backend-4xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.backend_4xx_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.backend_4xx_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Backend 4xx error detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Backend] 5xx メトリクスフィルター
# アクセスログから 5xx 系サーバーエラーをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "backend_5xx_metric_filter" {
  name           = "${var.project}-${var.environment}-backend-5xx-metric-filter"
  log_group_name = var.ecs_backend_log_group_name
  pattern        = "[ip, id, user, timestamp, request, status_code=5*, size]"

  metric_transformation {
    name          = "Backend5xxCount"
    namespace     = "${var.project}/${var.environment}/Backend"
    value         = "1"
    default_value = "0"
  }
}

# [Backend] 5xx アラーム — 5xx エラーを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "backend_5xx_alarm" {
  alarm_name          = "${var.project}-${var.environment}-backend-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.backend_5xx_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.backend_5xx_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Backend 5xx server error detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Backend] アプリケーションエラー メトリクスフィルター
# ERROR / Exception / Traceback を含むログをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "backend_error_metric_filter" {
  name           = "${var.project}-${var.environment}-backend-error-metric-filter"
  log_group_name = var.ecs_backend_log_group_name
  pattern        = "?ERROR ?Exception ?Traceback"

  metric_transformation {
    name          = "BackendErrorCount"
    namespace     = "${var.project}/${var.environment}/Backend"
    value         = "1"
    default_value = "0"
  }
}

# [Backend] アプリケーションエラー アラーム — エラーログを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "backend_error_alarm" {
  alarm_name          = "${var.project}-${var.environment}-backend-error"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.backend_error_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.backend_error_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Backend application error (ERROR/Exception/Traceback) detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Backend] タイムアウトエラー メトリクスフィルター
# timeout / timed out / TimeoutError を含むログをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "backend_timeout_metric_filter" {
  name           = "${var.project}-${var.environment}-backend-timeout-metric-filter"
  log_group_name = var.ecs_backend_log_group_name
  pattern        = "?timeout ?\"timed out\" ?TimeoutError"

  metric_transformation {
    name          = "BackendTimeoutCount"
    namespace     = "${var.project}/${var.environment}/Backend"
    value         = "1"
    default_value = "0"
  }
}

# [Backend] タイムアウト アラーム — タイムアウトを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "backend_timeout_alarm" {
  alarm_name          = "${var.project}-${var.environment}-backend-timeout"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.backend_timeout_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.backend_timeout_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Backend timeout error detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Backend] DB 接続エラー メトリクスフィルター（Backend 専用）
# OperationalError / InterfaceError / 接続失敗メッセージを含むログをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "backend_db_error_metric_filter" {
  name           = "${var.project}-${var.environment}-backend-db-error-metric-filter"
  log_group_name = var.ecs_backend_log_group_name
  pattern        = "?OperationalError ?InterfaceError ?\"could not connect\" ?\"connection refused\""

  metric_transformation {
    name          = "BackendDBErrorCount"
    namespace     = "${var.project}/${var.environment}/Backend"
    value         = "1"
    default_value = "0"
  }
}

# [Backend] DB 接続エラー アラーム — DB 接続失敗を検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "backend_db_error_alarm" {
  alarm_name          = "${var.project}-${var.environment}-backend-db-error"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.backend_db_error_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.backend_db_error_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Backend DB connection error (OperationalError/InterfaceError/connection refused) detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}


# ==============================================================================
# ========== FRONTEND ==========
# ==============================================================================

# ------------------------------------------------------------------------------
# [Frontend] 2xx メトリクスフィルター
# アクセスログから HTTP 200 レスポンスをカウントする
# 修正: パターンをプレーンテキスト形式に変更（JSON 形式から変更）
# 修正: alarm_actions / ok_actions を追加
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "frontend_metric_filter" {
  name           = "${var.project}-${var.environment}-frontend-metric-filter"
  log_group_name = var.ecs_frontend_log_group_name
  pattern        = "[ip, id, user, timestamp, request, status_code=200, size]"

  metric_transformation {
    name          = "FrontendHTTP200Count"
    namespace     = "${var.project}/${var.environment}/Frontend"
    value         = "1"
    default_value = "0"
  }
}

# [Frontend] 2xx アラーム — HTTP 200 を検知したら SNS に通知する
# 修正: alarm_actions（欠落していた）と ok_actions を追加
resource "aws_cloudwatch_metric_alarm" "frontend_metric_alarm" {
  alarm_name          = "${var.project}-${var.environment}-frontend-2xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.frontend_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.frontend_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Frontend HTTP 200 detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Frontend] 4xx メトリクスフィルター
# アクセスログから 4xx 系エラーレスポンスをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "frontend_4xx_metric_filter" {
  name           = "${var.project}-${var.environment}-frontend-4xx-metric-filter"
  log_group_name = var.ecs_frontend_log_group_name
  pattern        = "[ip, id, user, timestamp, request, status_code=4*, size]"

  metric_transformation {
    name          = "Frontend4xxCount"
    namespace     = "${var.project}/${var.environment}/Frontend"
    value         = "1"
    default_value = "0"
  }
}

# [Frontend] 4xx アラーム — 4xx エラーを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "frontend_4xx_alarm" {
  alarm_name          = "${var.project}-${var.environment}-frontend-4xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.frontend_4xx_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.frontend_4xx_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Frontend 4xx error detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Frontend] 5xx メトリクスフィルター
# アクセスログから 5xx 系サーバーエラーをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "frontend_5xx_metric_filter" {
  name           = "${var.project}-${var.environment}-frontend-5xx-metric-filter"
  log_group_name = var.ecs_frontend_log_group_name
  pattern        = "[ip, id, user, timestamp, request, status_code=5*, size]"

  metric_transformation {
    name          = "Frontend5xxCount"
    namespace     = "${var.project}/${var.environment}/Frontend"
    value         = "1"
    default_value = "0"
  }
}

# [Frontend] 5xx アラーム — 5xx エラーを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "frontend_5xx_alarm" {
  alarm_name          = "${var.project}-${var.environment}-frontend-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.frontend_5xx_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.frontend_5xx_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Frontend 5xx server error detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Frontend] アプリケーションエラー メトリクスフィルター
# ERROR / Exception / Traceback を含むログをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "frontend_error_metric_filter" {
  name           = "${var.project}-${var.environment}-frontend-error-metric-filter"
  log_group_name = var.ecs_frontend_log_group_name
  pattern        = "?ERROR ?Exception ?Traceback"

  metric_transformation {
    name          = "FrontendErrorCount"
    namespace     = "${var.project}/${var.environment}/Frontend"
    value         = "1"
    default_value = "0"
  }
}

# [Frontend] アプリケーションエラー アラーム — エラーログを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "frontend_error_alarm" {
  alarm_name          = "${var.project}-${var.environment}-frontend-error"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.frontend_error_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.frontend_error_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Frontend application error (ERROR/Exception/Traceback) detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Frontend] タイムアウトエラー メトリクスフィルター
# timeout / timed out / TimeoutError を含むログをカウントする
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "frontend_timeout_metric_filter" {
  name           = "${var.project}-${var.environment}-frontend-timeout-metric-filter"
  log_group_name = var.ecs_frontend_log_group_name
  pattern        = "?timeout ?\"timed out\" ?TimeoutError"

  metric_transformation {
    name          = "FrontendTimeoutCount"
    namespace     = "${var.project}/${var.environment}/Frontend"
    value         = "1"
    default_value = "0"
  }
}

# [Frontend] タイムアウト アラーム — タイムアウトを検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "frontend_timeout_alarm" {
  alarm_name          = "${var.project}-${var.environment}-frontend-timeout"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.frontend_timeout_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.frontend_timeout_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Frontend timeout error detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}

# ------------------------------------------------------------------------------
# [Frontend] バックエンド到達不能エラー メトリクスフィルター（Frontend 専用）
# ConnectionError / refused を含むログをカウントする
# Streamlit → FastAPI への接続失敗を検知する
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "frontend_backend_unreachable_metric_filter" {
  name           = "${var.project}-${var.environment}-frontend-backend-unreachable-metric-filter"
  log_group_name = var.ecs_frontend_log_group_name
  pattern        = "?ConnectionError ?refused"

  metric_transformation {
    name          = "FrontendBackendUnreachableCount"
    namespace     = "${var.project}/${var.environment}/Frontend"
    value         = "1"
    default_value = "0"
  }
}

# [Frontend] バックエンド到達不能 アラーム — 接続失敗を検知したら SNS に通知する
resource "aws_cloudwatch_metric_alarm" "frontend_backend_unreachable_alarm" {
  alarm_name          = "${var.project}-${var.environment}-frontend-backend-unreachable"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.frontend_backend_unreachable_metric_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.frontend_backend_unreachable_metric_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Frontend cannot reach backend (ConnectionError/refused) detected in logs."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_sendmsg_arn]
  ok_actions          = [var.sns_sendmsg_arn]
}