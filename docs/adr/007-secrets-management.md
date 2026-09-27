# 007. シークレットの持ち方の選定（Secrets Manager vs sops）

- **Status**: 採用 (Accepted)
- **Date**: 2026-09-27
- **出典**: Session 02 / [Issue #3](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/3)「バックエンドECS　⇒　Auroraへの接続ができない件について」
- **Related**: `modules/aurora/main.tf` / `modules/aurora/output.tf` / `modules/ecs/ecs-taskdef-backend.tf` / `modules/vpc/main.tf`（secretsmanager エンドポイント） / `modules/iam/main.tf`

## 背景

バックエンド（FastAPI）から Aurora（PostgreSQL互換）へ接続するための認証情報を、どこに置き、どうコンテナへ渡すかを決める必要があった。

候補は2つ。**Secrets Manager**（AWSマネージド／Auroraのマスターパスワード自動管理と統合）と **sops**（リポジトリ内に暗号化したまま秘密を置く）。

Issue #3 の記録では、この判断の帰結として次の3段階で失敗している。

1. `DB_HOST` の既定値が `localhost` のため接続拒否（`connection to server at "localhost" (127.0.0.1), port 5432 failed: Connection refused`）
2. 変数をタスク定義に注入した後、`ResourceInitializationError: unable to pull secrets or registry auth: unable to retrieve secret from asm ... context deadline exceeded`（Secrets Manager への到達経路が無い）
3. VPCエンドポイントを追加した後、`AccessDeniedException: ... is not authorized to perform: secretsmanager:GetSecretValue`（取得権限が無い）

すなわち **①値の置き場所、②取得経路、③取得権限** の3つが揃って初めて成立する。この問いは「暗号化するか」ではなく「誰がローテーションと注入経路を持つか」である。

## 現状の実装（As-Is）

| 項目 | 実装 | 定義 |
| --- | --- | --- |
| マスターパスワードの生成・保管 | `manage_master_user_password = true`（Aurora が Secrets Manager に自動管理） | `modules/aurora/main.tf` |
| ARN の受け渡し | Aurora が `master_user_secret[0].secret_arn` を出力 → `environments/dev/main.tf` で ecs モジュールへ注入 | `modules/aurora/output.tf` |
| コンテナへの注入 | `secrets = [{ name = "DB_PASSWORD", valueFrom = "${var.aws_rds_cluster_aurora_cluster_master_user_secret_arn}:password::" }]` | `modules/ecs/ecs-taskdef-backend.tf` |
| 非秘密の設定 | `environment` で `DB_HOST`（Aurora のクラスタエンドポイント）/ `DB_USER` / `DB_PORT` / `DB_NAME` を注入 | 同上 |
| 取得経路 | Interface VPCエンドポイント `com.amazonaws.ap-northeast-1.secretsmanager`（private DNS 有効、`vpc-endpoint-sg` の 443 を Fargate SG から許可） | `modules/vpc/main.tf` |
| 取得権限 | タスク実行ロールのインラインポリシーに `secretsmanager:GetSecretValue`（**`Resource = "*"`**、ポリシー名は `GetSercretValues` と綴り誤り） | `modules/iam/main.tf` |
| ローカル開発 | docker-compose で `POSTGRES_PASSWORD: postgres` を平文指定 | `docker/docker-compose.yml` |
| 副産物 | `environments/dev/errored.tfstate` に `secret_arn` が残存（配布物に混入） | — |

## 検討した選択肢

| 選択肢 | 評価 | 補足 |
| --- | --- | --- |
| **Secrets Manager（採用）** | ◎ | Aurora のマスターパスワード管理と統合でき、ECS の `secrets`（`valueFrom`）でネイティブに注入できる。IAM で取得主体を統制でき、VPCエンドポイントで経路も閉じられる |
| sops（リポジトリ内暗号化） | △ | 秘密を Git の中に置けるため「リポジトリ完結」に見えるが、**復号鍵（age/KMS）の配布と CI での取り扱いが別問題として残る**。Aurora の自動ローテーションと連動せず、ローテーションを自作することになる。また ECS の `secrets` 注入が使えず、アプリ起動時に復号するか起動スクリプトに組み込む必要があり、コンテナに鍵を渡す設計になる |
| SSM パラメータ（SecureString） | ○ | 安価で KMS 暗号化もできるが、Aurora のマスターパスワード自動管理（`manage_master_user_password`）と統合できず、ローテーションは手動運用になる |
| 環境変数に平文で注入 | × | タスク定義・コンソール・ログに残る。選択肢として成立しない |

## 決定

**DBの認証情報は Secrets Manager で管理し、ECS の `secrets` 機構でコンテナへ注入する。**

- パスワードは Aurora に生成・管理させ（`manage_master_user_password = true`）、Terraform は **ARN のみ** を扱う。これによりリポジトリに秘密が一切入らない
- 取得経路は VPCエンドポイント（NATレス構成を維持）、取得権限はタスク実行ロールで与える
- sops は採用しない。理由は暗号強度ではなく、**「ローテーション」と「コンテナへの注入経路」を AWS 側のマネージド機能に寄せられるか**という設計上の判断である。リポジトリ内に暗号文を持つ必然性が薄い

### あわせて是正すべき点（現行実装のままでは不十分）

| 重大度 | 内容 | 対応 |
| --- | --- | --- |
| 高 | `secretsmanager:GetSecretValue` の `Resource = "*"`。アカウント内の任意シークレットを読める | Aurora が出力するシークレットARNを変数で受け、`Resource` を限定する |
| 中 | ポリシー名の綴り誤り `GetSercretValues` | `GetSecretValue` に修正 |
| 中 | `errored.tfstate` に `secret_arn` が残存し、配布物に混入 | 成果物から除去。state は S3 バックエンドに集約し `encrypt = true` |
| 中 | コンテナ起動ごとに Secrets Manager への API 呼び出しが発生する | 取得失敗は `ResourceInitializationError` としてタスク起動失敗になる。経路（エンドポイント・SG・IAM）をデプロイ前のチェックリストに入れる |
| 低 | ローテーションの設計がない | マスターユーザーのパスワードは自動ローテーション対象になり得る。**ローテーション周期と、ローテーション直後にアプリが再接続できるか**を検証する |
| 低 | ローカル開発は平文 | `.env` を `.gitignore` 済みであることを前提に、開発環境でのみ許容する |

## 結果

**良い点**
- Terraform および Git に秘密が一切入らず、ARN の受け渡しだけで完結する
- ECS ネイティブの注入機構を使うためアプリ側に復号処理が不要で、`DB_PASSWORD` は AWS 側から環境変数として渡される
- 取得主体が IAM で統制でき、VPCエンドポイントにより経路も監査できる

**悪い点・トレードオフ**
- **コンテナ起動が Secrets Manager に依存する**。エンドポイント・SG・IAM のいずれかが欠けるとタスクが起動しない（Issue #3 で2回失敗した通り）。可用性設計上、この依存を明示して監視対象に含める必要がある
- シークレットの保管単価とAPI呼び出し課金が発生する
- sops を採らない以上、**AWS を経由しない経路では秘密を扱えない**（完全にオフラインのビルドやローカル検証では別の手段が必要）

## 学び

「Secrets Manager を使った」は対策の完了ではない。**①置き場所、②取得経路（ネットワーク）、③取得権限（IAM）、④取得した値が残る場所（state・ログ・イメージ）** の4点が揃って初めて成立する。Issue #3 は ①→②→③ の順に失敗しており、1つの事象（DBに接続できない）の下に性質の異なる3層の問題が隠れていた。

暗号化方式の比較（Secrets Manager か sops か）で判断すべきなのは「どちらが安全か」ではなく、**「ローテーションと注入経路の責任を誰に持たせるか」**である。AWS 上の到達経路が VPCエンドポイントで既に閉じている以上、リポジトリ内に秘密を持ち込む動機は小さいと判断した。

## 未確認事項

- マスターパスワードのローテーション周期は未設定／未確認。実際にローテーションが発生した際、稼働中タスクが新しいパスワードを取得できるか（再接続できるか）は未検証
- `errored.tfstate` に残る `secret_arn` が現時点で有効な値かは未確認（リソースは既に削除済みの可能性がある）
- IAM の `Resource` 限定を行った場合に、ECS の代理取得（実行ロール経由）が引き続き成功するかは実環境での確認が必要

## Links

- Issue: [#3 バックエンドECS　⇒　Auroraへの接続ができない件について](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/3)
- 既存ADR: [issue_list/0004-database-secrets-manager-and-db-endpoint.md](./issue_list/0004-database-secrets-manager-and-db-endpoint.md)、[issue_list/0003-cloudwatch-logs-vpc-endpoint.md](./issue_list/0003-cloudwatch-logs-vpc-endpoint.md)
- 関連ドキュメント: [security-design.md](./security-design.md) D-5 / D-8 / D-9、[network-design.md](./network-design.md) D-2
