# ADR-007. 初回デプロイ時のフロント⇒バックエンド

- **Status**: 採用 (Accepted)
- **Date**: 2026-09
- **Related Issues**: [#7](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7)

## 背景

GitHub Actions + Terraform で ECS(Fargate)へデプロイする構成で、フロントエンド(Streamlit)からバックエンド(FastAPI)への通信がデプロイ直後に失敗する事象が [#7](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7) で報告された。

当時の CI のデプロイ手順は以下のステップだった。

```yaml
      # -----------------------------------------------------------------
      # 4. タスク定義を更新（ECRにSHORT_SHAのイメージが存在するため成功する）
      # -----------------------------------------------------------------
      - name: Deploy Task Definitions
        working-directory: environments/dev
        run: |
          terraform apply -auto-approve \
            -var="backend_image_tag=${{ env.SHORT_SHA }}" \
            -var="frontend_image_tag=${{ env.SHORT_SHA }}" \
            -target=module.ecs.aws_ecs_task_definition.ecs_backend_taskdef \
            -target=module.ecs.aws_ecs_task_definition.ecs_frontend_taskdef

      # -----------------------------------------------------------------
      # 5. ECSサービスおよび残りすべてのインフラ（Cluster等）をデプロイ
      # -----------------------------------------------------------------
      - name: Deploy ECS Services & Entire Infrastructure
        working-directory: environments/dev
        run: |
          terraform apply -auto-approve \
            -var="backend_image_tag=${{ env.SHORT_SHA }}" \
            -var="frontend_image_tag=${{ env.SHORT_SHA }}"
```

ECS Service Connect では、バックエンドの ECS サービスがネームスペースに登録されて初めて `backend-service` という論理 DNS 名が解決できる。当時の手順ではステップ 2 の一括 `terraform apply` でフロントとバックの ECS サービスが同時に作成されるため、フロントエンドのタスク起動がバックエンドの登録・安定よりも先に走り、初回デプロイ時に名前解決が失敗して接続エラーが発生した。2 回目以降のデプロイではバックエンドが既に存在して登録済みのため解決が必ず成功し、「初回だけ失敗する」ように見える。

## 検討した選択肢

| 選択肢 | 評価 | 補足 |
|--------|------|------|
| **バックエンドを先行デプロイし、安定を待ってからフロントをデプロイ(採用)** | ◎ | Terraform の `-target` でバックエンド ECS サービスのみ先に適用し、`aws ecs wait services-stable` で到達可能を保証してからフロントを適用する。CI 上で決定的な順序になる |
| フロントエンドにリトライ・再試行ロジックを実装 | △ | 数回のリトライで一時的に症状を回避できる可能性はあるが、順序問題の根本原因は残り、タイムアウト設計が不確実になる |
| デプロイ手順をドキュメントで管理し、人の注意で順序を守る | × | 属人的で再発リスクが高い。「初回失敗→再デプロイで成功」のような不安定な状態を生み続ける |


## 決定

**CI/CD ワークフローを「① バックエンド ECS サービスのみ先行適用 → ② `aws ecs wait services-stable` で安定確認 → ③ フロントエンド ECS サービスを含む残りのインフラを一括適用」の順序に分割する。あわせて、フロントエンドの `BACKEND_URL` は未設定時に即エラーにするのをやめ、ECS Service Connect のサービス名をデフォルト値として利用する。**

- CI: 「Deploy Backend ECS Service(`-target=module.ecs.aws_ecs_service.backend`)」→「Wait for Backend ECS Service to become Stable」→「Deploy Frontend ECS Service & Entire Infrastructure」の 3 ステップに分割
- フロントエンド: `BACKEND_URL = os.getenv("BACKEND_URL", "http://backend-service:8000")` とし、Service Connect の DNS 名にフォールバック

## 結果

**良い点**

- 初回デプロイでもバックエンドが Service Connect に登録され安定してからフロントが起動するため、名前解決失敗が発生しない
- 順序が CI のコードとして表現されるため、人為ミスによる再発がない
- フロントエンドでの指数関数バックオフでのリトライ接続処理よりも確実に接続できる。

**悪い点**

- 運用において、必ずCICDからデプロイしなければいけないという周知は必要

## 学び

「初回だけ失敗して再デプロイで治る」ように見える障害は、たいていタイミング依存の初期化順序が原因である。今回も一見ランダムに見えたが、実態は Service Connect のネームスペース登録とフロントエンドのタスク起動の競合という**決定的な順序依存**だった。ランダムに見える挙動ほど初期化の順序と CI の実行順を疑うべきであり、待つべき完了条件(サービスの安定)は `wait` コマンドで CI 上に明示的に制御する、という切り分けの視点が得られた。

## Links

- Issue #7: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7
- 修正コミット: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/commit/232c59c9ce9bb03e9d86de5cd168ae7ee3989bf4
