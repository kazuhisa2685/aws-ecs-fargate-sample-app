locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------
resource "aws_iam_role" "fis_experiment_role" {
  name = "fis-experiment-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "fis.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fis_ecs_access" {
  role       = aws_iam_role.fis_experiment_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSFaultInjectionSimulatorECSAccess"
}

resource "aws_fis_experiment_template" "fargate_cpu_stress_test" {
  description = "Fargate CPU stress test via SSM sidecar"
  role_arn    = aws_iam_role.fis_experiment_role.arn

  # 対象となるECSタスクの指定
  target {
    name           = "FargateTaskTarget"
    resource_type  = "aws:ecs:task"
    selection_mode = "PERCENT(100)"
  }

  # Fargate専用のCPUストレステスト用アクション
  action {
    name      = "InjectCPULoad"
    action_id = "aws:ecs:task-cpu-stress"

    target {
      key   = "Tasks"
      value = "FargateTaskTarget"
    }
  }

  stop_condition {
    source = "none"
  }
}