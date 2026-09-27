# 008. フロントエンド → バックエンドの名前解決方式の選定（ECS Service Connect）

- **Status**: 採用 (Accepted)
- **Date**: 2026-09-27
- **出典**: [Issue #1](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/1)「フロントエンドECS　⇒　バックエンドECSへの接続ができない件について」 / [Issue #7](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7)「初回デプロイ時のバックエンド接続エラー」
- **Related**: `modules/ecs/ecs-cluster.tf` / `modules/ecs/ecs-service-backend.tf` / `modules/ecs/ecs-service-frontend.tf` / `modules/ecs/ecs-taskdef-backend.tf` / `docker/sample-dev-frontend/app.py` / `.github/workflows/deploy-all.yml`

## 背景

フロントエンド（Streamlit）からバックエンド（FastAPI）を呼び出す際の**接続先をどう解決するか**を決める必要があった。

Issue #1 の記録では、まずアプリケーション側の既定値が原因で失敗している。

```
バックエンドへの接続に失敗しました: HTTPConnectionPool(host='localhost', port=8000): Max retries exceeded
```

原因は `BACKEND_URL` の既定値が `http://localhost:8000` であり、コンテナ内の `localhost` は自分自身を指すため通信が拒否されたこと。Issue には「**ネットワークの問題ではない**」と明記されており、切り分けを誤らせる症状であったことが分かる。対処として ①Service Connect による名前解決、②フロント側の接続先変更 の2つが実施された。

さらに Issue #7 で、**初回デプロイ時のみ**接続エラーが発生する問題が記録されている。

> バックエンドが立ち上がる⇒ServiceConnectで名前解決を行う⇒ほぼ同時にフロントが立ち上がり、バックエンドのURLが完成する前にBACKEND_URLを参照する。⇒名前解決ができずにエラー発生。

対処としてデプロイ手順に `aws ecs wait services-stable` が挿入された。

## 現状の実装（As-Is）

| 項目 | 実装 | 定義 |
| --- | --- | --- |
| アプリ側の既定値 | `BACKEND_URL = os.getenv("BACKEND_URL", "http://backend-service:8000")`（既定がサービスディスカバリ名に変更済み） | `docker/sample-dev-frontend/app.py` |
| 名前空間 | `aws_service_discovery_http_namespace` を `${project}-${environment}-namespace` として作成し、クラスタの `service_connect_defaults` に既定として設定 | `modules/ecs/ecs-cluster.tf` |
| バックエンド側の公開 | `service_connect_configuration` で `discovery_name = "backend-service"`、`port_name = "backend-port"`、`client_alias { port = 8000, dns_name = "backend-service" }` | `modules/ecs/ecs-service-backend.tf` |
| ポート名の整合 | タスク定義の `portMappings.name = "backend-port"`（`service_connect_configuration.port_name` と一致させる必要がある旨がコメントで明記） | `modules/ecs/ecs-taskdef-backend.tf` |
| フロントエンド側 | フロントにも `service_connect_configuration` を定義 | `modules/ecs/ecs-service-frontend.tf` |
| デプロイ順序 | バックエンドのタスク定義・サービスを適用した後、フロントエンドをデプロイ。間に `aws ecs wait services-stable` を挿入 | `.github/workflows/deploy-all.yml` |
| 内部ALB | **存在しない**（ALBはインターネット向けの1台のみ。バックエンドTGはそのALB配下） | `modules/alb/main.tf` |

## 検討した選択肢

| 選択肢 | 評価 | 補足 |
| --- | --- | --- |
| **ECS Service Connect（採用）** | ◎ | 名前解決とクライアントサイドロードバランシングをECSが提供する。追加のロードバランサ（固定費・リスナー・ヘルスチェック設定）を持ち込まずに済み、環境ごとの名前空間に閉じたサービス名で呼べる |
| 内部ALB を別途作成 | △ | 名前解決は提供でき、ヘルスチェックでデプロイをゲートできるが、**サービスごとにALB／リスナー／ターゲットグループが必要**になり固定費と設定量が増える。フロント→バックの通信はHTTPの単純なAPI呼び出しで、ALBのL7機能（パスベースルーティング等）を必要としていない |
| 環境変数に接続先を直書き | × | **Issue #1 の再発そのもの**。既定値が実環境と乖離してもアプリは正常に起動するため、「起動しているのに通信だけ失敗する」という切り分けの難しい障害になる |
| Cloud Map（サービスディスカバリ）を直接利用 | ○ | Service Connect は内部で Cloud Map を利用する。直接使う場合はクライアント側にDNS解決と負荷分散の考慮が必要になる |
| バックエンドを同一タスクのサイドカーにする | × | フロントとバックのライフサイクルが同一になり、Issue #7 のコメントでも指摘された「1タスク内で2プロセスが同一ポートを奪い合う」構成に戻る |

## 決定

**フロントエンド → バックエンドの名前解決には ECS Service Connect を採用する。**

- バックエンドは `discovery_name = "backend-service"` / `port_name = "backend-port"` で自身を公開し、フロントエンドは `http://backend-service:8000` で呼び出す
- アプリケーションの既定値は **ローカル用の `localhost` ではなくサービスディスカバリ名**にする。コンテナ内の `localhost` は自分自身を指すため、既定値として成立しない
- 内部ALB は採用しない。理由は「ALBが不要」なのではなく、**この通信にALBの機能を必要としていないのに、サービス数分の固定費と設定を払うことになる**ためである
- 名前解決はサービス起動と同時には完了しないため、**デプロイ順序を設計に含める**。バックエンドの `services-stable` を待ってからフロントエンドをデプロイする

## 結果

**良い点**
- サービス単位の名前（`backend-service`）で呼べるため、タスクのIPやタスク数（`desired_count`）に依存しない
- ロードバランサを増やさずに済み、名前空間が環境ごとに分離される（`${project}-${environment}-namespace`）
- タスク定義のポート名と Service Connect の `port_name` の整合を Terraform で一元管理できる

**悪い点・トレードオフ**
- **名前解決の完了とアプリの起動順序が独立している**。Service Connect の名前解決が整う前にクライアントが起動すると接続に失敗する（Issue #7 で顕在化）。そのためデプロイ手順に待機ステップが必須になる
- 待機ステップはパイプラインの実行時間を延ばす
- Service Connect の名前空間・サービス定義はECS側の管理対象であり、内部ALBのようにヘルスチェックで「どの版を通すか」を明示的に制御する仕組みは持たない

## 学び

**接続先の「既定値」は、環境が変われば必ず嘘になる。** `os.getenv("BACKEND_URL", "http://localhost:8000")` はローカル開発のための妥当な既定値だが、コンテナでは自分自身を指すため、**ネットワークは正常なのにアプリだけが失敗する**という切り分けの難しい症状を生む。Issue #1 に「ネットワークの問題ではない」と記録されていることが、この症状の性質をよく示している。

また、名前解決は「仕組みを入れる」だけでは完結せず、**起動順序まで含めて設計対象**である。サービスディスカバリを導入した結果として、デプロイ手順に待機が必要になった（Issue #7）。仕組みの導入と、それを運用する手順はセットで設計しなければならない。

## 未確認事項

- Service Connect の名前解決に実際に要する時間（実測）は未確認。`aws ecs wait services-stable` が初回デプロイに対して十分な待機になっているかは、複数回の初回デプロイで検証する必要がある
- `.github/workflows/deploy-all.yml` の `aws ecs wait services-stable` が **フロント／バックのどの時点に挿入されているか**の最終確認（Issue #7 の記載と現行ファイルの記述が一致するか）
- フロントエンド側 `service_connect_configuration` の役割設定（クライアント専用か、公開も含むか）の詳細は未確認

## Links

- Issue: [#1 フロントエンドECS　⇒　バックエンドECSへの接続ができない件について](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/1)、[#7 初回デプロイ時のバックエンド接続エラー](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/7)
- 既存ADR: [issue_list/007-container-communication-endpoint-resolution.md](./issue_list/007-container-communication-endpoint-resolution.md)
- 関連ドキュメント: [network-design.md](./network-design.md)、[cicd-design.md](./cicd-design.md)
