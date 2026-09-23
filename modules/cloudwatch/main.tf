resource "aws_cloudwatch_metric_filter" "example" {
  name           = "example-metric-filter"
  log_group_name = aws_cloudwatch_log_group.example.name
  pattern        = "{ $.statusCode = 200 }"

  metric_transformation {
    name      = "example-metric"
    namespace = "example-namespace"
    value     = "1"
  }
}