# 004. 初回デプロイの段階的 `terraform apply` の採用

- **Status**: 採用 (Accepted)
- **Date**: 2026-09-06
- **Related Issues**: [#4](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/4)

## 背景

新規環境構築時など、Terraform State が空の状態で `terraform apply` を実行すると、タスク定義で指定した ECR イメージ(`SHORT_SHA` タグ)が存在しないためデプロイが失敗する。

原因

1. タスク定義がコミットハッシュ(`SHORT_SHA`)タグのイメージを参照しているため、ECR 上に該当イメージが無いとエラーになる
2. `SHORT_SHA` は GitHub Actions のデプロイを経由しないと決まらない。つまり一番最初の Terraform デプロイ時にはタグ名が `latest` としてデフォルト設定されており、「そんなタグはない」としてタスク実行に失敗する

## 決定要因

1. `latest` ではなく `SHORT_SHA` で一意管理したい→ タグ運用を変えたくない
2. 手作業でのコンソール操作(手動で ECR を作る等)は IaC の精神に反するので避けたい
3. 初回デプロイも含めて GitHub Actions だけで完結させたい

## 検討した選択肢

| 選択肢 | 評価 | 補足 |
|--------|------|------|
| **GitHub Actions 内で `-target` を使った段階的 apply (採用)** | ◎ | コード変更は workflow のみ。IaC の一貫性を保ったまま初回を自動化できる |
| タスク定義のイメージタグを `latest` 固定にする | × | トレーサビリティが失われる。どのコミットが動いているか追えなくなる |
| ECR だけ手動/別 pipeline で先行作成する | × | 「インフラは全部 Terraform で」という前提が崩れる。手順が増え再現性が落ちる |

## 決定

**GitHub Actions 内で `-target` オプションを使い、デプロイを 4 段階に分けて実行する。**

```yaml
# 1. ECR を含む基礎インフラのみ先行作成
- run: terraform apply -auto-approve -target=module.vpc -target=module.ecr

# 2. ECR へ Docker Image を Build & Push
- run: |
    docker build -t $ECR_REGISTRY/sample-dev-backend:$SHORT_SHA .
    docker push $ECR_REGISTRY/sample-dev-backend:$SHORT_SHA

# 3. タスク定義を適用
- run: terraform apply -auto-approve -target=module.ecs.aws_ecs_task_definition.ecs_backend_taskdef

# 4. ECS サービスを含めた全インフラを適用
- run: terraform apply -auto-approve
```

対応コミット: [`717db37`](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/commit/717db3733a9e7b66020bda48)

## 結果

**良い点**

- 空の state からの初回デプロイが完全自動で通るようになった
- `SHORT_SHA` タグ運用を維持でき、イメージのトレーサビリティが保たれる

**悪い点**

- ローカルでのデプロイはできない。するとしてもスクリプトなどを作らないといけない。

## 学び

`-target` は本来「避けるべき」機能だが、**ECR というリソース作成と、そこへのアーティファクト Push という IaC の外側のプロセス**が依存ループを形成するケースでは、実務上の妥協として有力な選択肢になる。

## Links

- Issue #4: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/4
- 対応コミット: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/commit/717db3733a9e7b66020bda48
