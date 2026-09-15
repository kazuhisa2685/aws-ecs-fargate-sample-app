# 0002. コンテナ間通信のエンドポイント解決方法 (localhost 排除)

- **Status**: 採用 (Accepted)
- **Date**: 2026-09
- **Related Issues**: [#1](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/1), [#7](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7)

## Context (背景)

Streamlit(フロントエンド)から FastAPI(バックエンド)への通信で、初回デプロイ時に以下のエラーが発生した。

```text
HTTPConnectionPool(host='localhost', port=8000): Max retries exceeded with url: /memos
(Caused by NewConnectionError("HTTPConnection(host='localhost', port=8000):
Failed to establish a new connection: [Errno 111] Connection refused"))
```

さらに [#7](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7) では、**初回デプロイ時のみバックエンド接続エラーが出るが、2 回目のデプロイ(ECS 更新)をするとなぜか治る**という一見ランダムな事象として顕在化した。

ECS では各タスク(コンテナ)が独立したネットワーク名前空間を持つ。ローカルの docker compose とは異なり、**`localhost` は自分自身のコンテナしか指さない**。フロントエンドの接続先が localhost 固定だったため、バックエンドが別タスクで動いている ECS 環境では接続が必ず失敗する。

「2 回目で治る」ように見えたのは、再デプロイの過程で環境変数やタスク定義が正しい値に更新されるタイミングがあったためであり、本質的には設定の不備だった。

## Decision Drivers (決定要因)

1. コンテナ間通信は ECS 内の DNS/サービスディスカバリまたは ALB 経由で解決すべき
2. 接続先ホスト名をソースコードにハードコードせず、環境変数で差し替え可能にする
3. ローカル開発(docker compose)と ECS 両方で動く設定にしたい

## Considered Options (検討した選択肢)

| 選択肢 | 評価 | 補足 |
|--------|------|------|
| **Cloud Map (Service Connect / Service Discovery) で内部 DNS 解決 (採用)** | ◎ | ECS ネイティブな正攻法。タスク定義の環境変数にサービス名を渡すだけでよい |
| ALB を経由させてフロント→バックを外部ループさせる | × | 通信が VPC の外周を回る設計になり非効率。バックエンドはインターネットに公開すべきでない |
| 1 タスクにフロント/バックを共存させ localhost で通信 | × | スケールとデプロイの独立姓が失われる。アンチパターン |
| 接続先を IP 直指定 | × | タスクの IP は起動のたびに変わるため不可 |

## Decision Outcome (決定)

**バックエンドの接続先を `localhost` から、ECS のサービスディスカバリで解決されるバックエンドサービスの DNS 名に変更する。接続先は環境変数化し、タスク定義(Terraform)から注入する。**

- フロントエンド: `API_BASE_URL` 環境変数でバックエンドのエンドポイントを受け取る
- バックエンドも DB 接続先を同様に環境変数化(→ [ADR-0004](0004-database-secrets-manager-and-db-endpoint.md))

## Consequences (結果)

**良い点**

- コンテナの配置や IP を意識せず、論理名でサービス間通信できる
- ローカル(docker compose)と本番(ECS)で環境変数を変えるだけで同じコードが動く

**悪い点**

- 初見では「ローカルでは動くのに ECS で動かない」原因の切り分けに時間を要した(コンテナのネットワーク名前空間の理解が前提になる)

## 学び

「localhost で動く」はコンテナオーケストレーション上では一切保証されない。docker compose と ECS の違いの本質は **各コンテナが独立したホストとして振る舞う** ことである。初回だけ失敗し再デプロイで治る類の障害は「偶然治った」に見えて実は設定反映の順序やタイミングの問題であることが多く、ランダムに見える障害こそ設定を疑うべきという切り分け力が身についた。

## Links

- Issue #1: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/1
- Issue #7: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7
- 修正コミット: https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/commit/d33cf67d3b445fec65f96b3257137e1fb6983698
