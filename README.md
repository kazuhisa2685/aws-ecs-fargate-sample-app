# AWS Webアプリケーション基盤

AWS上にWebアプリケーションを構築することを想定し、**可用性・スケーラビリティ・セキュリティ・運用性**を重視して設計したAWSインフラ構成です。

単純にAWSサービスを並べるのではなく、以下のビジネス要件から各AWSサービスの採用理由と設計方針を決定しています。

---

## 1. プロジェクト概要

### 目的

WebアプリケーションをAWS上に構築し、通常時の安定したAPI処理に加えて、予測困難なトラフィック増加やAZ障害に対しても継続的にサービスを提供できる基盤を構築する。

### 想定アプリケーション

* Webアプリケーション
* REST APIを中心としたバックエンド
* ECS/Fargate上でコンテナアプリケーションを実行
* Aurora Serverless v2をデータベースとして利用

---

# 2. ビジネス要件

| 項目        | 要件                      |
| --------- | ----------------------- |
| システム      | Webアプリケーション             |
| 通常時トラフィック | 約10 req/sec             |
| 夜間トラフィック  | 日中の約1/3（約3 req/sec）     |
| トラフィック特性  | 変動が激しく、事前予測が困難          |
| 可用性       | マルチAZ構成                 |
| 障害時       | AZ障害発生時もサービス継続          |
| 性能        | 障害発生時も可能な限り通常時と同等の性能を維持 |
| セキュリティ    | アプリケーション・DB・認証情報を分離して保護 |
| 運用        | ログ・メトリクスを一元管理           |

---

# 3. アーキテクチャ概要

![AWS Architecture](./docs/architecture.png)

### トラフィックフロー

```text
Client
  ↓
Amazon API Gateway
  ↓
Application Load Balancer
  ↓
Amazon ECS / Fargate
  ↓
Amazon Aurora Serverless v2
```

アプリケーションコンテナはPrivate Subnetに配置し、外部から直接アクセスできない構成とする。

---

# 4. AWSサービス構成

| AWSサービス                     | 用途                     |
| --------------------------- | ---------------------- |
| Amazon API Gateway          | APIのエントリーポイント          |
| Application Load Balancer   | ECSタスクへのトラフィック分散       |
| Amazon ECS                  | コンテナオーケストレーション         |
| AWS Fargate                 | コンテナ実行基盤               |
| Amazon ECR                  | コンテナイメージ管理             |
| Amazon Aurora Serverless v2 | リレーショナルデータベース          |
| Amazon VPC                  | ネットワーク基盤               |
| Internet Gateway            | インターネット接続              |
| NAT Gateway                 | Private Subnetからの外部通信  |
| VPC Endpoint                | AWSサービスへのPrivate接続     |
| AWS Secrets Manager         | DB認証情報等の機密情報管理         |
| Amazon CloudWatch           | ログ・メトリクス監視             |
| IAM                         | AWSリソースへのアクセス制御        |
| EC2                         | 開発・運用用途                |
| Amazon S3                   | アプリケーション等から利用するAWSリソース |

---

# 5. ネットワーク設計

## VPC

VPCを以下のように論理分割する。

```text
VPC
├── Public Subnet
│   └── ALB
│
├── Private Subnet（Application）
│   ├── ECS Fargate
│   └── ECS Fargate
│
├── Private Subnet（DB）
│   └── Aurora Serverless v2
│
└── Private Subnet / VPC Endpoint
    └── AWSサービスへのPrivate接続
```

Availability Zoneを複数利用し、単一AZへの依存を排除する。

---

# 6. マルチAZ設計

本構成では、アプリケーション層・ロードバランサ層・データベース層をマルチAZで構成する。

### Application Layer

ECS Serviceを複数AZへ分散配置する。

```text
AZ-A
  ECS Task
  ECS Task

AZ-C
  ECS Task
  ECS Task
```

これにより、1つのAZで障害が発生した場合でも、正常なAZでアプリケーション処理を継続できる。

### Load Balancer

ALBを複数AZに配置し、正常なターゲットへ自動的にトラフィックを分散する。

### Database

AuroraのDB Subnet Groupを複数AZにまたがって構成し、AZ障害時にもDBサービスを継続できる構成とする。

---

# 7. ECS / Fargate設計

## Fargate採用理由

コンテナ実行基盤としてFargateを採用する。

主な理由は以下。

* EC2インスタンスの管理が不要
* コンテナ単位でリソースを定義可能
* ECS Service Auto Scalingと組み合わせて水平スケール可能
* トラフィック変動に対して柔軟に対応可能
* AZをまたいだタスク配置が容易

---

# 8. スケーリング設計

今回の要件では、

> トラフィックの変動が激しく、予想ができない

という特徴がある。

そのため、固定台数での運用ではなく、**需要に応じてECSタスク数を自動調整する設計**とする。

### ECS Service Auto Scaling

例えば以下のメトリクスを利用してスケーリングを行う。

* CPU使用率
* Memory使用率
* ALB RequestCountPerTarget

特にHTTP APIの場合、CPU使用率だけでは実際のリクエスト量を正確に捉えられない可能性があるため、`RequestCountPerTarget`もスケーリング指標として検討する。

### スケールイメージ

```text
通常時

AZ-A     AZ-C
Task     Task
  ↓        ↓
      ALB


トラフィック増加

AZ-A     AZ-C
Task     Task
Task     Task
Task     Task
   ↓       ↓
       ALB


トラフィック減少

AZ-A     AZ-C
Task     Task
  ↓        ↓
      ALB
```

---

# 9. 障害時の性能維持

本システムでは、単純な「サービス停止を防ぐ」だけではなく、

> AZ障害時にも可能な限り通常時と同等の処理能力を維持する

ことを設計目標とする。

例えば、通常時に2台のタスクで処理している場合、1AZ障害によって片側のタスクが全滅すると、残存AZだけで処理することになる。

そのため、以下の考え方を採用する。

### N+1のキャパシティ確保

```text
通常時

AZ-A
  ECS × 2

AZ-C
  ECS × 2

合計4 Task


AZ-A障害

AZ-A
  × 障害

AZ-C
  ECS × 2
```

障害時にも必要な処理能力を確保できるよう、最低タスク数・スケーリング上限・各タスクのCPU/Memoryを要件から決定する。

単に「マルチAZにする」だけでは性能維持は保証できないため、**障害時に残存AZがどれだけの負荷を処理できるか**をキャパシティ設計で検証する。

---

# 10. Aurora Serverless v2

データベースにはAurora Serverless v2を採用する。

### 採用理由

今回のシステムではトラフィック変動が激しいため、DBについても負荷に応じてコンピューティングリソースを調整できる構成が適している。

Aurora Serverless v2により、アプリケーション側のスケールに合わせてDB側のキャパシティも柔軟に調整する。

### 設計ポイント

* DB Subnet Groupを複数AZに配置
* アプリケーションからDBへ直接インターネット経由で接続させない
* Security Groupによって接続元をECSに限定
* 最小/最大ACUをワークロードから決定
* DB接続数についても監視・チューニングする

---

# 11. セキュリティ設計

## Security Group

Security Groupによって通信経路を最小限にする。

基本的な通信関係は以下。

```text
API Gateway
    ↓
ALB
    ↓
ECS
    ↓
Aurora
```

### ALB

ALBではHTTP/HTTPS等の必要なポートのみ許可する。

### ECS

ECSではALBからの通信のみを許可する。

```text
ALB SG
  ↓
ECS SG
```

### Aurora

AuroraではECSからのDB接続のみを許可する。

```text
ECS SG
  ↓
Aurora SG
```

このようにSecurity Groupをレイヤーごとに分離し、不要な通信を許可しない。

---

# 12. Secrets Manager

DBのユーザー名・パスワード等の機密情報は、Terraformやソースコードへ直接記載しない。

AWS Secrets Managerで管理し、ECSタスクから必要なタイミングで参照する。

```text
Secrets Manager
      ↑
      │
     IAM
      │
      ↓
ECS Task
```

これにより、認証情報のハードコーディングを防止する。

---

# 13. IAM設計

IAM Roleは用途ごとに分離する。

例：

```text
ECS Task Execution Role
  ├── ECR Image Pull
  ├── CloudWatch Logs
  └── Secrets Manager

ECS Task Role
  └── アプリケーションが必要とするAWS APIのみ許可
```

Principle of Least Privilege（最小権限の原則）に基づき、不要なAWS権限を付与しない。

---

# 14. ECR

DockerコンテナイメージはAmazon ECRで管理する。

```text
Developer
    ↓
Docker Build
    ↓
ECR
    ↓
ECS Fargate
```

ECS Task DefinitionからECR上のイメージを指定し、Fargateで実行する。

---

# 15. CloudWatch

運用時の可観測性を確保するため、CloudWatchを利用する。

監視対象の例：

### ECS

* CPU使用率
* Memory使用率
* Running Task数
* Desired Task数

### ALB

* RequestCount
* TargetResponseTime
* HTTP 4xx
* HTTP 5xx
* HealthyHostCount
* UnHealthyHostCount

### Aurora

* CPUUtilization
* DatabaseConnections
* ACU使用状況
* FreeableMemory
* Read/Write負荷

### ログ

ECSコンテナログをCloudWatch Logsへ集約する。

---

# 16. 可用性設計

可用性を高めるため、単一障害点（SPOF）を可能な限り排除する。

| コンポーネント         | 可用性対策           |
| --------------- | --------------- |
| API Gateway     | AWSマネージドサービスを利用 |
| ALB             | マルチAZ           |
| ECS             | 複数AZへTaskを分散    |
| Fargate         | サーバーレス実行基盤      |
| Aurora          | マルチAZ           |
| VPC             | 複数AZのSubnetを利用  |
| Secrets Manager | AWSマネージドサービス    |
| CloudWatch      | AWSマネージドサービス    |

---

# 17. 障害シナリオ

## AZ障害

### Before

```text
AZ-A                 AZ-C

ECS × 2              ECS × 2
   ↓                    ↓
       Application
```

### AZ-A障害

```text
AZ-A                 AZ-C
  ×                  ECS × 2
                       ↓
                   Application
```

ALBは正常なターゲットへトラフィックを送信し、ECS Serviceは必要に応じてタスクを再配置・起動する。

ただし、**「AZ障害時にも性能を維持する」ためには、残存AZのキャパシティが十分であることが前提**となる。

そのため、設計段階で負荷試験を実施し、必要なタスク数・CPU/Memory・スケーリング設定を決定する。

---

# 18. セキュリティ境界

本構成では、インターネットからDBやECSへ直接アクセスできないよう、ネットワークレイヤーを分離する。

```text
Internet
   │
   ▼
API Gateway
   │
   ▼
ALB
   │
   ▼
Private Subnet
   │
   ▼
ECS Fargate
   │
   ▼
Private DB Subnet
   │
   ▼
Aurora
```

特にDBはPrivate Subnetへ配置し、外部公開しない。

---

# 19. 設計上の重要な判断

## なぜEC2ではなくFargateなのか

今回の要件ではトラフィック変動が大きく、アプリケーションの処理能力を柔軟に変更できることが重要である。

Fargateを利用することで、EC2インスタンスのキャパシティ管理を減らし、ECS Service単位でアプリケーションをスケールできる。

---

## なぜAurora Serverless v2なのか

トラフィック変動が大きいため、DBについても固定キャパシティではなく、ワークロードに応じてコンピューティングキャパシティを調整できる構成を採用する。

---

## なぜマルチAZなのか

単一AZ障害によってアプリケーション全体が停止するリスクを排除するため。

ただし、マルチAZ化だけでは性能維持は保証できない。

**「障害時に残存AZだけで必要な処理能力を確保できるか」までをキャパシティ設計として検討する。**

---

# 20. API Gateway + ALB構成について

API GatewayをAPIの入口として配置し、その後段にALBを配置することで、APIの公開入口とコンテナへのトラフィック制御を分離する。

ただし、API GatewayからPrivateなALBへ接続する場合は、**VPC Link等の接続方式を明確に設計する必要がある**。

本ポートフォリオでは、単にサービスを配置するだけではなく、

* API Gateway → ALB間の接続方式
* ALBのInternal / Internet-facing
* VPC Link
* Security Group
* HTTPS/TLS
* WAF
* API認証・認可

までを今後の詳細設計で詰める。

---

# 21. インフラストラクチャコード

Infrastructure as CodeとしてTerraformによる構築を想定する。

```text
Terraform
    │
    ├── VPC
    ├── Subnet
    ├── Route Table
    ├── Security Group
    ├── ALB
    ├── ECS
    ├── Fargate
    ├── Aurora
    ├── Secrets Manager
    ├── VPC Endpoint
    └── IAM
```

TerraformによってAWSリソースをコード化し、環境差分を管理可能にする。

---

# 22. 設計・実装で重視したポイント

本ポートフォリオでは、AWSサービスの利用経験だけではなく、以下の観点から設計を行っている。

### 可用性

* Multi-AZ
* ECS Taskの分散配置
* Auroraの冗長化
* Health Check
* 自動復旧

### スケーラビリティ

* ECS Service Auto Scaling
* Fargate
* Aurora Serverless v2
* ALBによる負荷分散

### セキュリティ

* Private Subnet
* Security Groupによる通信制御
* IAM Least Privilege
* Secrets Manager
* DB非公開

### 可観測性

* CloudWatch Logs
* CloudWatch Metrics
* ALB Metrics
* ECS Metrics
* Aurora Metrics

### 運用性

* TerraformによるIaC
* コンテナイメージのECR管理
* ログの一元管理
* 自動スケーリング

---

# 23. 今後の改善項目

現時点では基本アーキテクチャを中心に設計しており、以下を詳細化する予定。

* [ ] API GatewayとALB間の接続方式を確定
* [ ] AWS WAFの導入検討
* [ ] API認証・認可方式の決定
* [ ] ECS Auto Scalingの具体的な閾値設計
* [ ] Aurora Serverless v2のMin/Max ACU設計
* [ ] 負荷試験によるキャパシティ検証
* [ ] AZ障害を想定したカオス・障害試験
* [ ] CloudWatch Alarm設計
* [ ] SNS等を利用したアラート通知
* [ ] Terraform Module化
* [ ] CI/CDパイプライン構築
* [ ] Blue/Green Deploymentの導入
* [ ] RTO / RPOの定義
* [ ] バックアップ・リストア設計
* [ ] コスト最適化

---

# 24. 設計成果物

本ポートフォリオでは、単純なTerraformコードだけではなく、実務の設計工程を意識して以下の成果物を作成する。

```text
docs/
├── architecture.md
├── architecture.png
├── network-design.md
├── security-design.md
├── availability-design.md
├── scaling-design.md
├── monitoring-design.md
├── disaster-recovery.md
└── load-test.md
```

---

# 25. Summary

本システムでは、以下を実現することを目標とする。

* Multi-AZによる高可用性
* ECS/Fargateによる柔軟なスケーリング
* Aurora Serverless v2によるDBキャパシティの柔軟性
* ALBによる負荷分散
* Private Subnetによるアプリケーション・DBの保護
* Secrets Managerによる機密情報管理
* IAMによる最小権限アクセス
* CloudWatchによる可観測性
* TerraformによるInfrastructure as Code
* 障害時のキャパシティを考慮した設計
* 負荷試験・障害試験による設計妥当性の検証

最終的には、**「構成図を作った」ポートフォリオではなく、「要件定義 → 基本設計 → 詳細設計 → IaC → 試験 → 運用設計」まで一貫して考えたAWS設計案件**として完成させる。
