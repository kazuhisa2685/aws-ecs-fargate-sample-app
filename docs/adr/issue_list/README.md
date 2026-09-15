# ADR: アーキテクチャ決定記録 (Architecture Decision Records)

このディレクトリは、[aws-ecs-fargate-sample-app](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app) の開発過程で下した技術的決定を **ADR (Architecture Decision Record)** として記録するものである。

各 ADR は実際に起きたトラブル(= GitHub Issues)を出発点とし、「なぜその解決策を選んだのか」「他の選択肢をなぜ捨てたのか」を MADR 形式で記述している。

## 採用システムと前提

本アプリは Streamlit(フロントエンド)+ FastAPI(バックエンド)+ Aurora(PostgreSQL) を、AWS ECS Fargate 上で ALB 経由に公開する構成。インフラは Terraform で管理し、デプロイは GitHub Actions で自動化している。

```text
GitHub Actions (CI/CD)
  └─ Terraform apply
       └─ VPC (private subnet 構成)
            ├─ ECS Fargate: Streamlit (frontend)
            ├─ ECS Fargate: FastAPI (backend)
            │    ├─ Secrets Manager から DB 認証情報を取得
            │    └─ CloudWatch Logs へログ出力 (VPC endpoint 経由)
            ├─ Aurora PostgreSQL
            └─ ALB (HTTP 8000 / 8001 ルーティング)
```

## ADR 一覧

| ADR | タイトル | 状態 | 元 Issue |
|-----|---------|------|----------|
| [0001](0001-adopt-ecs-fargate-terraform-cicd.md) | デプロイ基盤として ECS Fargate × Terraform × GitHub Actions を採用 | 採用 (Accepted) | - |
| [0002](0002-container-communication-endpoint-resolution.md) | コンテナ間通信のエンドポイント解決方法 (localhost 排除) | 採用 (Accepted) | [#1](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/1), [#7](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7) |
| [0003](0003-cloudwatch-logs-vpc-endpoint.md) | プライベートサブネットからの CloudWatch Logs 出力に VPC Endpoint を採用 | 採用 (Accepted) | [#2](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/2) |
| [0004](0004-database-secrets-manager-and-db-endpoint.md) | DB 接続先の configurable 化と認証情報の Secrets Manager 管理 | 採用 (Accepted) | [#3](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/3) |
| [0005](0005-staged-terraform-apply-for-initial-deploy.md) | 初回デプロイの鶏と卵問題に対する段階的 `terraform apply` の採用 | 採用 (Accepted) | [#4](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/4) |
| [0006](0006-alb-health-check-configuration.md) | ALB ヘルスチェックの正しいターゲット設定 | 採用 (Accepted) | [#6](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/6) |

## ADR 化の対象外とした Issue

| Issue | タイトル | 対象外の理由 |
|-------|---------|-------------|
| [#5](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/5) | aurora (modules/aurora/ が git 追跡されない) | アーキテクチャ上の意思決定を含まない、Git 操作起因の一時的トラブルのため |
| #8 | (取得不可) | 本 ADR 作成時点で内容を取得できなかったため、推測で作成せず除外 |

## ADR の形式 (MADR)

各 ADR は以下の構成で統一している。

- **Status**: 提案 / 採用 / 非推奨 などの状態
- **Context (背景)**: どんな問題に直面したか
- **Decision Drivers (決定要因)**: 何を考慮すべき制約・要件だったか
- **Considered Options (検討した選択肢)**: 何を比較したか、なぜ落としたか
- **Decision Outcome (決定)**: 何を採用したか
- **Consequences (結果)**: 良い点 / 悪い点
- **学び**: この決定から得られた教訓
- **Links**: 元 Issue・コミット
