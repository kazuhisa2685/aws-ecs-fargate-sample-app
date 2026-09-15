# 0001. デプロイ基盤として ECS Fargate × Terraform × GitHub Actions を採用

- **Status**: 採用 (Accepted)
- **Date**: 2026-09
- **Related Issues**: 本 ADR は後続のすべての ADR (0002〜0006) の前提となる決定

## Context (背景)

Streamlit(フロントエンド)+ FastAPI(バックエンド)+ PostgreSQL 系 DB からなるアプリケーションを、ポートフォリオとして外部に公開する必要があった。

単一 EC2 への docker compose デプロイも可能だったが、以下を重視した。

- クラウドネイティブな AWS マネージドサービスでの運用経験を示したい
- インフラをコードで再現可能にしたい(手作業でのコンソール構築を排除)
- デプロイを push をトリガーに自動化したい

## Decision Drivers (決定要因)

1. **運用工数を抑えたい**: サーバーのパッチ適用やキャパシティ管理はしたくない
2. **IaC による再現性**: 手順書ではなくコードでインフラを表現したい
3. **CI/CD との一体性**: イメージタグをコミットハッシュ (`SHORT_SHA`) で一意に管理し、トレーサビリティを確保したい
4. **コスト**: 学習用途のため、常時課金が最小であることが望ましい

## Considered Options (検討した選択肢)

| 選択肢 | 評価 | 採用しなかった理由 |
|--------|------|--------------------|
| **EC2 + docker compose** | △ | 最も簡単だが、サーバー管理・手動デプロイが残る。オーケストレーションの学びが薄い |
| **ECS on EC2 (EC2 起動タイプ)** | △ | コストを最適化できるが、インスタンス管理が発生し Fargate の旨味がない |
| **EKS** | × | 本規模では過剰。クラスタ自体の運用コスト(コントロールプレーン料金)が高い |
| **App Runner / Lambda** | × | 2 コンテナ構成とヘルスチェック・サイドカー的な自由度の観点で制約が大きい |
| **ECS Fargate (採用)** | ◎ | サーバーレスでコンテナ完結。Terraform と GitHub Actions との親和性が高い |

## Decision Outcome (決定)

**ECS Fargate を実行基盤とし、インフラは Terraform で、CI/CD は GitHub Actions で構築する。**

- イメージは ECR にプッシュし、タグは GitHub のコミットハッシュ (`SHORT_SHA`) を使用する
- タスク定義のイメージタグもこの `SHORT_SHA` を参照する(この判断が [ADR-0005](0005-staged-terraform-apply-for-initial-deploy.md) の初回デプロイ問題を生むことになる)

## Consequences (結果)

**良い点**

- サーバー管理ゼロでコンテナを稼働させられる
- Terraform state を通じてインフラ全体の差分管理ができる
- コミットハッシュタグにより「どのコミットが動いているか」が即座に追跡できる

**悪い点**

- Terraform 初回適用時の「ECR が無いのにタスク定義がイメージを参照する」問題が発生した(→ [ADR-0005](0005-staged-terraform-apply-for-initial-deploy.md) で解決)
- Fargate + Aurora の組み合わせは学習用途としてはコストが高くなりがちで、停止運用の工夫が必要

## 学び

インフラ構成の選択は「何を学びたいか」と「何を運用から排除したいか」のトレードオフで決めるべき。本プロジェクトでは ECS Fargate を選んだことで、後に VPC Endpoint・Secrets Manager・ALB ヘルスチェックなど、**マネージドサービス間のネットワーク境界で発生する実践的な問題**を多数経験できた。EC2 で素通りできていた層の問題が可視化されるのは Fargate 選択の大きな副次効果だった。

## Links

- リポジトリ: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app
- 関連 ADR: [0005](0005-staged-terraform-apply-for-initial-deploy.md)
