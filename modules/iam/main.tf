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