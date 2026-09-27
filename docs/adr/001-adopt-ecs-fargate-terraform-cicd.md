# 001. デプロイ基盤として ECS Fargate × Terraform × GitHub Actions を採用

- **Status**: 採用 (Accepted)
- **Date**: 2026-09
- **Related Issues**: -

## 背景

Streamlit(フロントエンド)+ FastAPI(バックエンド)+ PostgreSQL 系 DB からなるアプリケーションを、ポートフォリオとして外部に公開する必要があった。

単一 EC2 への docker compose デプロイも可能だったが、以下を重視した。

- クラウドネイティブな AWS マネージドサービスでの運用経験を示したい
- インフラをコードで再現可能にしたい(手作業でのコンソール構築を排除)
- デプロイを push をトリガーに自動化したい(EC2でもできなくはないが、ECRにpushするほうが簡単という意味で)

## 決定要因

1. **運用工数を抑えたい**: サーバーのパッチ適用やキャパシティ管理はしたくない
2. **IaC による再現性**: 手順書ではなくコードでインフラを表現したい
3. **CI/CD との一体性**: イメージタグをコミットハッシュ (`SHORT_SHA`) で一意に管理し、トレーサビリティを確保したい
4. **コスト**: 学習用途のため、常時課金が最小であることが望ましい

## 検討した選択肢

| 選択肢 | 評価 | 採用しなかった理由 |
|--------|------|--------------------|
| **EC2 + docker compose** | △ | 最も簡単だが、サーバー管理・手動デプロイが残る。 |
| **ECS on EC2 (EC2 起動タイプ)** | △ | コストを最適化できるが、インスタンス管理が発生する。 |
| **EKS** | × | 本規模では過剰。クラスタ自体の運用コスト(コントロールプレーン料金)が高い。そもそも kubernetes を今回は使用しない。 |
| **ECS Fargate (採用)** | ◎ | サーバーレスでコンテナ完結。Terraform と GitHub Actions との親和性が高い |

## 決定

**ECS Fargate を実行基盤とし、インフラは Terraform で、CI/CD は GitHub Actions で構築する。**

- イメージは ECR にプッシュし、タグは GitHub のコミットハッシュ (`SHORT_SHA`) を使用する
- タスク定義のイメージタグもこの `SHORT_SHA` を参照する。

## 結果

**良い点**

- サーバー管理ゼロでコンテナを稼働させられる
- Terraform state を通じてインフラ全体の差分管理ができる
- コミットハッシュタグにより「どのコミットが動いているか」が即座に追跡できる

**悪い点**

- Terraform 初回適用時の「ECR が無いのにタスク定義がイメージを参照する」問題が発生した(→ [004](004-staged-terraform-apply-for-initial-deploy.md) で解決)

## Links

- リポジトリ: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app
- 関連 ADR: [004](004-staged-terraform-apply-for-initial-deploy.md) 
