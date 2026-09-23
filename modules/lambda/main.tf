data "archive_file" "CallDevopsAgent_zip" {
  type        = "zip"
  source_file = "${path.module}/src/CallDevopsAgent/CallDevopsAgent.py"  # Lambda関数のコードを含むPythonファイル
  output_path = "${path.module}/src/CallDevopsAgent/CallDevopsAgent.zip"  # ZIPファイルの出力先
}

data "archive_file" "SendMsg_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/SendMsg"
  output_path = "${path.module}/src/SendMsg/SendMsg.zip"
  
  # 出力される SendMsg.zip 自体が再帰的に取り込まれるのを防ぐための除外設定
  excludes    = ["SendMsg.zip"]
}

data "aws_ssm_parameter" "devops_agent_name_space" {
  name = "/devops-agent/devops_agent_space_id"
}

data "aws_ssm_parameter" "slack_webhook_url" {
  name = "/devops-agent/slack_webhook_url"
}

resource "aws_lambda_function" "CallDevopsAgent" {
  filename         = data.archive_file.CallDevopsAgent_zip.output_path
  function_name    = var.call_devops_agent_name
  role            = var.call_devops_agent_role_arn
  handler         = "CallDevopsAgent.lambda_handler"
  runtime         = "python3.14"
  timeout         = 600
  environment {
    variables = {
      ENV = var.environment
      SLACK_WEBHOOK_URL = data.aws_ssm_parameter.slack_webhook_url.value
      DEVOPS_AGENT_SPACE_ID = data.aws_ssm_parameter.devops_agent_name_space.value
    }
  }
}

resource "aws_lambda_function" "SendMsg" {
  filename         = data.archive_file.SendMsg_zip.output_path
  function_name    = var.send_msg_name
  role            = var.send_msg_role_arn
  handler         = "SendMsg.lambda_handler"
  runtime         = "python3.14"
  timeout         = 600
  environment {
    variables = {
      ENV = var.environment
      SLACK_WEBHOOK_URL = data.aws_ssm_parameter.slack_webhook_url.value
    }
  }
}