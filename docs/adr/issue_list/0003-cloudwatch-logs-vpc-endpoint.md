# 0003. プライベートサブネットからの CloudWatch Logs 出力に VPC Endpoint を採用

- **Status**: 採用 (Accepted)
- **Date**: 2026-09
- **Related Issues**: [#2](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/2)

## Context (背景)

ECS Fargate のタスクを**プライベートサブネット**に配置したところ、コンテナのログが CloudWatch Logs に一切出力されない問題が発生した。

ECS の `awslogs` ログドライバは、タスク実行ロールの権限とは別に、**タスク自身が CloudWatch Logs の API エンドポイントに到達できること**を要求する。プライベートサブネットからはインターネット(NAT 経由)へ出られない構成だったため、ログの送信に失敗していた。

## Decision Drivers (決定要因)

1. タスクはプライベートサブネットに置きたい(セキュリティ上、DB 接続を受けるバックエンドを公開したくない)
2. ログは必ず CloudWatch Logs に集約したい(デバッグ・トレーサビリティの要)
3. NAT Gateway は月額固定で高額なため、学習用途では避けたい

## Considered Options (検討した選択肢)

| 選択肢 | 評価 | 補足 |
|--------|------|------|
| **CloudWatch Logs 向け VPC Endpoint (Interface 型) を追加 (採用)** | ◎ | VPC 内から直接 CloudWatch Logs API に到達できる。必要なのは `com.amazonaws.<region>.logs` のみ |
| NAT Gateway を経由させる | × | 月額固定 + データ転送料が高く、ログ出力のためだけに常設するには過剰 |
| タスクをパブリックサブネットに移す | × | セキュリティ設計を崩す。バックエンドを公開ネットワークに置く動機がない |

## Decision Outcome (決定)

**VPC Endpoint (`com.amazonaws.ap-northeast-1.logs`) を Terraform で作成し、プライベートサブネットから CloudWatch Logs への到達性を確保する。**

併せて以下も整理した。

- タスク定義の `containerDefinitions.logConfiguration` でロググループを明示:

```json
"logConfiguration": {
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "/ecs/sample-dev-backend",
    "awslogs-region": "ap-northeast-1",
    "awslogs-stream-prefix": "ecs",
    "awslogs-create-group": "true"
  }
}
```

- タスク実行ロール (`EcsTaskExecutionRole`) に `logs:CreateLogStream` / `logs:PutLogEvents` を付与(`AmazonECSTaskExecutionRolePolicy` 相当の権限)

## Consequences (結果)

**良い点**

- プライベートサブネット構成を維持したままログを収集できる
- NAT Gateway を常設せずに済む(コスト面で大きい)

**悪い点**

- VPC Endpoint は 1 つあたり約 $0.01/時間(月額 7 超ドル程度)の固定費がかかる
- Logs 用だけ作っても、ECR からイメージを Pull する等の他の AWS API 呼び出しには別の Endpoint(`ecr` `s3` `secretsmanager` 等)が別途必要になる。実際、後の Secrets Manager 問題([ADR-0004](0004-database-secrets-manager-and-db-endpoint.md))でも同種の到達性問題が再発した

## 学び

「AWS のマネージドサービスは裏で HTTPS API である」という一点に帰着する。プライベートサブネットに置いたリソースは、**どの AWS API と話すのかを明示し、その経路(VPC Endpoint or NAT)を設計する**必要がある。VPC Endpoint は「無料の魔法の口」ではなく用途ごとに作るものなので、構成図を描いて通信経路を先に列挙する癖がついた。

## Links

- Issue #2: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/2
- 関連コミット: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/commit/b7247ecfe26811ee24ebca4e8c8bea89f6a22ae9
