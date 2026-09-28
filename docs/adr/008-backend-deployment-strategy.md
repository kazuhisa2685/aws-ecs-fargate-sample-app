# 008. バックエンドのデプロイ方式の選定（ECS標準 Blue/Green vs ローリング更新）

- **Status**: 採用 (Accepted)
- **Date**: 2026-09-27
- **出典**: Session 02
- **Related**: `modules/ecs/ecs-service-backend.tf` / `modules/ecs/ecs-service-frontend.tf` / `modules/alb/main.tf` / `modules/iam/main.tf`（LB用インフラロール） / [issue_list/0006-alb-health-check-configuration.md](./issue_list/0006-alb-health-check-configuration.md) / [Issue #6](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/6)

## 背景

バックエンド（およびフロントエンド）のコンテナを更新するとき、**どの方式で新バージョンへ切り替えるか**を決める必要があった。

検討対象は、ECSが標準で提供する **Blue/Green（`deployment_configuration { strategy = "BLUE_GREEN" }`）** と、従来型の **ローリング更新** である。判断に影響したのは、この基盤が「AZ障害時もサービス継続」「障害時も可能な限り通常時と同等の性能を維持」を要件としている点、そして実際に [Issue #6] で `Task failed ELB health checks` によりタスクが停止ループに陥った経験がある点である。デプロイ時に異常をどう検出してどう戻すかは、可用性要件と直結する。

## 検討した選択肢

| 選択肢 | 評価 | 補足 |
| --- | --- | --- |
| **ECS標準 Blue/Green（採用）** | ◎ | 新バージョンを別のターゲットグループで起動し、**テストリスナーで検証してから本番の重みを切り替えられる**。切替は重みの変更のみであるため、問題発生時は重みを戻すだけで即座に旧バージョンへ復帰できる。`deployment_circuit_breaker` の `rollback = true` と組み合わせると、ヘルスチェック失敗時に自動で旧バージョンへ戻せる |
| ローリング更新（`deployment_controller` を `ECS` のままローリング既定で運用） | △ | 追加リソース（2本目のターゲットグループ・テストリスナー・リスナールール・ECS用のLB操作ロール）が一切不要で、構成は最も単純。しかし**切替中は新旧のタスクが混在して同一トラフィックを処理する**ため、「新バージョンのみを検証してから流す」ことができない。ロールバックも「新しいデプロイをやり直す」形になり、切り戻しに時間がかかる。`deployment_minimum_healthy_percent` / `maximum_percent` を設計して容量を担保する必要も生じる |
| CodeDeploy による Blue/Green | ○ | カナリア／リニアの段階シフトやライフサイクルフックが使え、統制はより強くなる。ただし CodeDeploy アプリケーション・デプロイグループ・サービスロールが加わり、**ECSの標準機能で足りる範囲を超えて構成要素が増える**。まずはECS標準で要件を満たす |
| 2つのALBを使い分ける | × | リスナー重複と固定費の増加に対して得られる利点が無い |

## 決定

**ECS標準の Blue/Green（`strategy = "BLUE_GREEN"` ＋ サーキットブレーカー `rollback = true`）を採用する。**

- 新バージョンは別ターゲットグループで起動し、**テストリスナーで検証した後に本番の重みを100/0から切り替える**。切り戻しは重みを戻す操作であり、再デプロイを必要としない
- ローリングを採らない理由は「構成が複雑だから」ではなく、**切替中の混在期間を許容したくないこと**、および**ロールバックの実効時間**である。可用性と性能の維持を要件に掲げる以上、切替と復帰が即時に行える方式を優先する
- ALB側のリスナールールには `lifecycle { ignore_changes = [action] }` を設定し、**重みの書き換えはECSの責務である**ことをコード上で明示する

### あわせて是正すべき点

| 重大度 | 内容 | 対応 |
| --- | --- | --- |
| 高 | ヘルスチェックの正常判定に最大180秒（`interval = 60` × `healthy_threshold = 3`）かかる一方、`bake_time_in_minutes = 1`（60秒）でベイクが完了する。**検証が完了する前に本番切替へ進む可能性がある** | `interval` を15〜30秒に短縮し、`bake_time` を3〜5分に設定して整合させる |
| 高 | テストリスナーが `0.0.0.0/0` に開放されており、**検証中の新バージョンが第三者から到達可能** | シークレットヘッダー条件、または検証端末のCIDR限定で保護する |
| 中 | サーキットブレーカーはヘルスチェック起因のみ（`alarms` 未指定）。5xx増加などの業務的な異常では自動ロールバックしない | CloudWatchアラームを `deployment_circuit_breaker.alarms` に指定し、観測ベースのロールバックを追加する（[monitoring-design.md](./monitoring-design.md) D-6） |
| 中 | Blue/Green は「2世代が同時に動く」前提のため、DBスキーマ変更との整合が必要 | 破壊的なスキーマ変更は2世代互換の手順（expand-contract）で行うことを規約化する |
| 中 | `ignore_changes = [task_definition]` により、**新リビジョンが実際にサービスへ適用されるかがワークフロー側の責務**になっている | デプロイ経路を明示する（[cicd-design.md](./cicd-design.md) D-5） |

## 結果

**良い点**
- 新旧のどちらにトラフィックを流すかを重みで制御でき、**切替と切り戻しが秒単位**で行える
- 本番へ流す前にテストリスナーで新バージョンを検証できる。Issue #6 の `Task failed ELB health checks` のような事象を、本番影響の前に検出できる
- サーキットブレーカー（`enable = true` / `rollback = true`）により、異常時は自動で旧バージョンに戻る

**悪い点・トレードオフ**
- サービスごとにターゲットグループ2本・リスナー2本・リスナールール2本、加えてECSがLBを操作するためのIAMロールが必要になり、**設定項目と検証対象が増える**
- **テストリスナーという公開経路が新たに生まれる**。保護しない限り攻撃面になる（現状は未保護）
- `bake_time` とヘルスチェックの整合という、特有のチューニング対象が生じる
- 2世代が同時に稼働するため、DBスキーマや外部I/Fの互換性を常に意識する必要がある
- ローリングと比べて、必要なタスク数（2世代分の容量）が一時的に増える

## 学び

デプロイ方式の選択は「切り替えの見た目」ではなく、**「異常に気づく手段があるか」「戻すのに何分かかるか」**で決めるべきである。ローリングは構成が単純で魅力的だが、混在期間中に問題が起きたときの切り戻しが再デプロイになり、要件が掲げる「障害時も可能な限り通常時と同等の性能を維持」と噛み合わない。

一方で Blue/Green を選ぶと、**テストリスナーという新しい入口**、`bake_time` という新しい待ち時間、2世代分の容量という新しいコストが同時に発生する。つまり方式の選択は、可用性の改善と引き換えに**守るべき対象を増やす**取引である。導入した仕組み（テストリスナー）を保護対象に加えるところまでが1セットだと捉えるべきであり、本件ではテストリスナーの保護が未対応として残っている。

## 未確認事項

- 実際の切り戻し所要時間（重みを戻して旧タスクへ復帰するまで）は未計測
- `bake_time_in_minutes = 1` で運用した場合に、実際に不整合な切替が発生しているかは、デプロイ履歴の確認が必要
- `deployment_circuit_breaker` に `alarms` を追加した場合の挙動（アラーム状態での自動ロールバック）は未検証
- ECS標準Blue/Greenにおける `ignore_changes = [task_definition]` の影響（新リビジョンが反映されるか）は [ADR-011](./011-initial-deploy-bootstrap.md) の未確認事項と同一

## Links

- 関連Issue: [#6 ALBからのアクセスに失敗。](https://github.com/kazuhisa2685/aws-ecs-fargate-sample-app/issues/6)
- 既存ADR: [issue_list/0006-alb-health-check-configuration.md](./issue_list/0006-alb-health-check-configuration.md)
- 関連ドキュメント: [scaling-design.md](./scaling-design.md) D-6、[security-design.md](./security-design.md) D-4、[cicd-design.md](./cicd-design.md) D-5、[011-initial-deploy-bootstrap.md](./011-initial-deploy-bootstrap.md)
