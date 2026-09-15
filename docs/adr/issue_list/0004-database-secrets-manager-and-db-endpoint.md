# 0004. DB 接続先の configurable 化と認証情報の Secrets Manager 管理

- **Status**: 採用 (Accepted)
- **Date**: 2026-09
- **Related Issues**: [#3](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/3)

## Context (背景)

FastAPI バックエンドから Aurora PostgreSQL への接続で、複数段階の障害が連続して発生した。

1. まずアプリケーションログに以下のエラー:

```text
sqlalchemy.exc.OperationalError: (psycopg2.OperationalError)
connection to server at "localhost" (127.0.0.1), port 5432 failed: Connection refused
```

2. DB 接続先を環境変数で差し替え、Secrets Manager から認証情報を取得する構成に移行したところ、今度はタスク起動時に:

```text
ResourceInitializationError: unable to pull secrets or registry auth...
failed to fetch secret... AccessDeniedException:
User: ... is not authorized to perform: secretsmanager:GetSecretValue
```

つまり「DB 接続先が localhost 固定」→「接続先は直せたが認証情報の取得権限がない」という、設定と権限の二段階問題だった。

## Decision Drivers (決定要因)

1. DB 接続先・認証情報をソースコードにハードコードしない
2. 認証情報は環境変数に平文で埋め込むのではなく、Secrets Manager から取得する
3. ECS のタスク起動シーケンス内でシークレットを解決できる必要がある

## Considered Options (検討した選択肢)

| 選択肢 | 評価 | 補足 |
|--------|------|------|
| **Secrets Manager + タスク定義の `secrets` フィールド (採用)** | ◎ | タスク起動時に ECS がシークレットを解決して環境変数へ注入する正攻法 |
| SSM Parameter Store | ○ | より安価だが、シークレットのローテーション・監査機能は Secrets Manager が優位。学習目的で Secrets Manager を採用 |
| 環境変数に直接平文で埋め込む | × | Terraform state やタスク定義に平文が残り、漏洩面が悪い |
| イメージに設定を焼き込む | × | 環境ごとの差し替えが効かず、イメージの再ビルドが必要になる |

## Decision Outcome (決定)

**DB 接続情報(ホスト/ユーザー/パスワード)は Secrets Manager に保存し、ECS タスク定義の `secrets` フィールド経由でコンテナの環境変数に注入する。**

対応内容:

- アプリ側: SQLAlchemy の接続文字列を `localhost` 固定から環境変数(`DATABASE_URL` 等)参照に変更
- インフラ側: タスク定義に `secrets` ブロックを追加し、Secrets Manager の ARN を参照
- 権限: `AccessDeniedException` に対して、**タスク実行ロール(タスク起動時にシークレットを取得する主体)** に `secretsmanager:GetSecretValue` を付与。ポイントは、アプリケーションではなく **ECS エージェント側のロール**がこの取得を行うという理解

## Consequences (結果)

**良い点**

- 認証情報がコード・state に平文で現れなくなり、セキュリティ姿勢が大きく向上
- 接続先の変更が環境変数の差し替えだけで済む

**悪い点**

- タスク実行ロール(起動時)とタスクロール(実行時)の権限の違いという理解コストが増えた
- Secrets Manager は 1 シークレットあたり月額 $0.40 + API 料金がかかる
- プライベートサブネットから Secrets Manager の API にも到達性が必要で、VPC Endpoint の追加対象が増えた([ADR-0003](0003-cloudwatch-logs-vpc-endpoint.md) と同型の問題)

## 学び

ECS には **タスク実行ロール (Task Execution Role)** と **タスクロール (Task Role)** という 2 つの IAM ロールがある。シークレット取得やイメージ Pull は前者、アプリ実行時の AWS API 呼び出しは後者という切り分けを、`AccessDeniedException` を通じて体で覚えた。また「Connection refused は到達性、AccessDenied は権限」と、エラーの種類で原因の層を切り分けるデバッグの型が身についた。

## Links

- Issue #3: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/3
- 関連 ADR: [0002](0002-container-communication-endpoint-resolution.md) (接続先の環境変数化), [0003](0003-cloudwatch-logs-vpc-endpoint.md) (VPC Endpoint)
