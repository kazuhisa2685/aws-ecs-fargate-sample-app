# AWS アカウント ID とリージョンを自動取得
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ssm_parameter" "devops_agent_name_space" {
  name            = "/devops-agent/devops_agent_space_id"
  with_decryption = true
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

###############################################
# IAM
###############################################

# 1. EC2用のIAMロールを作成
resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 2. SSMに必要なAWS管理ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. インスタンスプロファイルを作成
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

################################################
# Blue/Greenデプロイ用のIAMロールを作成
################################################

resource "aws_iam_role" "ecs_infrastructure_role_for_load_balancers" {
  name        = "EcsInfrastructureRoleForLoadBalancers"
  description = "Allows ECS to create and manage AWS resources on your behalf."

  # 信頼関係
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_service_role" {
  role       = aws_iam_role.ecs_infrastructure_role_for_load_balancers.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role_policy_attachment" "ecs_infrastructure_role_policy_for_load_balancers" {
  role       = aws_iam_role.ecs_infrastructure_role_for_load_balancers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForLoadBalancers"
}

# ECSタスク実行用のIAMロールを作成
resource "aws_iam_role" "ecs_task_execution_role" {
  name        = "EcsTaskExecutionRole"
  description = "Allows ECS tasks to call AWS services on your behalf."

  # 信頼関係
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECSタスク実行用のIAMロールにSecrets Managerへのアクセス権限を付与

resource "aws_iam_role_policy" "get_secret_values" {
  name = "GetSercretValues"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}


#-----------------------------------------------------------
# CallDevopsAgent Lambda Function
#-----------------------------------------------------------
resource "aws_iam_role" "call_devops_agent_role" {
  name = "call-devops-agent-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "call_devops_agent_policy" {
  name        = "CallDevopsAgent_policy"
  description = "IAM policy for Lambda logging to CloudWatch and interacting with AI DevOps Agent"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/CallDevopsAgent:*"
        ]
      },
      {
        Sid    = "UseDevopsAgent"
        Effect = "Allow"
        Action = [
          "aidevops:CreateChat",
          "aidevops:SendMessage",
          "aidevops:ListChats"
        ]
        Resource = [
          "arn:aws:aidevops:${local.region}:${local.account_id}:agentspace/${data.aws_ssm_parameter.devops_agent_name_space.value}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "call_devops_agent_policy_attachment" {
  policy_arn = aws_iam_policy.call_devops_agent_policy.arn
  role       = aws_iam_role.call_devops_agent_role.name
}

#-----------------------------------------------------------
# SendMsg Lambda Function
#-----------------------------------------------------------
resource "aws_iam_role" "send_msg_role" {
  name = "send-msg-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "send_msg_policy" {
  name        = "SendMsg_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLogGroupCreation"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:*"
        ]
      },
      {
        Sid    = "AllowSendMsgLogging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/SendMsg:*"
        ]
      },
      {
        Sid    = "AllowWeatherFunctionLogQueries"
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/get_all_weather_function:*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/get_all_weather_function"
        ]
      },
      {
        Sid    = "AllowInvokeDevopsAgent"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:${local.region}:${local.account_id}:function:CallDevopsAgent"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "send_msg_policy_attachment" {
  policy_arn = aws_iam_policy.send_msg_policy.arn
  role       = aws_iam_role.send_msg_role.name
}