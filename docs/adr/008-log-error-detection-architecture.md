# ADR-008. CloudWatch Logs のエラー検知方式の選定（Metric Filter vs Subscription Filter）

- **Status**: 採用 (Accepted)  
- **Date**: 2026-09  

---

## 背景

Lambda のエラー検知と DevOps Agent への自動解析依頼を行う仕組みを構築するにあたり、CloudWatch Logs のどの検知方式を採用するかが課題となった。

候補は以下の 2 つである。

1. **Subscription Filter**  
   - ログ本文をそのまま Lambda にストリームできる  
   - エラー行を即時に Lambda に渡せる  
   - DevOps Agent に直接解析依頼できる

2. **Metric Filter + CloudWatch Alarm**  
   - ログを数値化してアラームを発火  
   - Lambda はアラームをトリガーに Logs Insights で過去ログをまとめて取得  
   - DevOps Agent には「まとめられたログ」を渡す

一見すると Subscription Filter の方がシンプルで、ログ本文を直接 Lambda に渡せるため DevOps Agent 連携にも向いているように見える。しかし、実際の運用では大量ログ・誤検知・Lambda の同時実行数枯渇などの問題が顕在化するため、どちらを採用すべきか慎重な検討が必要だった。

---

## 検討した選択肢

| 選択肢 | 評価 | 補足 |
|--------|------|------|
| **Metric Filter + Alarm + Lambda + Logs Insights（採用）** | ◎ | ログ量に依存せず安定。Lambda の起動回数が一定で DevOps Agent の負荷も制御できる。過去10分のログをまとめて解析できる |
| Subscription Filter でログ本文を直接 Lambda に渡す | △ | ログ量が多いと Lambda が大量起動し、DevOps Agent に大量の解析依頼が飛ぶ。誤検知やコスト増のリスクが高い |
| Lambda 側でログのバッチング・キューイングを実装 | × | CloudWatch Logs のストリーム特性上、Lambda 側でのバッチングは困難。複雑化し保守性が低下する |
| DevOps Agent 側で大量リクエストを吸収する仕組みを作る | × | AgentSpace の実行数が爆増しコストが跳ね上がる。根本的な問題解決にならない |

---

## 選定理由（Metric Filter を採用した背景）

### 1. **Subscription Filter は大量ログで Lambda が爆発する**
Subscription Filter はログ行数に比例して Lambda が起動する。

- 1秒間に100行ログ → Lambda が100回起動  
- Lambda が100回 DevOps Agent に問い合わせ  
- AgentSpace の実行数が急増  
- コスト・同時実行数・負荷が跳ね上がる

ログ量が多い現場では致命的であり、安定運用が困難。

### 2. **Metric Filter はログ量に依存しない（Lambda が1回だけ起動）**
Metric Filter はログを数値化するため、ログ量が多くても Lambda の起動回数は一定。

- ERROR が 1 回出た → メトリクス 1  
- 10,000 行ログが出ても → メトリクスは 1 回だけ増える  

結果として、

- Lambda は 1 回だけ起動  
- DevOps Agent への問い合わせも 1 回だけ  
- コストが安定  
- 同時実行数枯渇のリスクがゼロ

### 3. **Logs Insights で「過去10分のログをまとめて取得」できる**
Metric Filter 方式では Lambda が Logs Insights を使い、必要なログだけをまとめて取得できる。

- ERROR 行だけ抽出  
- 複数ロググループを横断  
- 過去10分だけ  
- 1回のクエリで全部取れる  

DevOps Agent に渡すログは「まとめられた1つの結果」になるため、解析効率も高い。

### 4. **運用実績が豊富で壊れにくい**
Metric Filter + Alarm は AWS の標準的な運用パターンであり、SRE チームが安心して扱える。

Subscription Filter はログフォーマットの揺れや誤検知が多く、運用負荷が高い。

---

## 決定

**CloudWatch Logs のエラー検知方式として「Metric Filter + CloudWatch Alarm」を採用し、Lambda 側で Logs Insights を用いて過去10分のエラーをまとめて取得し、DevOps Agent に解析依頼する構成とする。**

- Subscription Filter は大量ログ時の Lambda 多重起動・DevOps Agent への大量問い合わせのリスクが高いため採用しない
- Metric Filter はログ量に依存せず安定して動作し、Lambda の起動回数を制御できる
- Logs Insights により、DevOps Agent に渡すログを「まとめた1件」にできるため、解析効率が高い

---

## 結果

**良い点**

- 大量ログでも Lambda の起動回数が一定で、DevOps Agent の負荷が安定する  
- 過去10分のログをまとめて解析できるため、誤検知やノイズが減る  
- CloudWatch Alarm の運用実績が豊富で、SRE が安心して扱える  
- Subscription Filter のような大量起動・誤検知のリスクがない

**悪い点**

- ログ本文をリアルタイムに Lambda に渡すことはできない  
- Logs Insights のクエリ実行コストが発生する（ただし少額）

---

## 学び

ログ検知方式は「ログをどう扱いたいか」だけでなく、  
**ログ量・Lambda の同時実行数・外部サービス（DevOps Agent）の負荷**まで含めて設計すべきである。

Subscription Filter はシンプルだが、大量ログ環境では破滅的な挙動をする。  
一方、Metric Filter はログ本文を直接渡せないという制約があるものの、  
**安定性・コスト・運用性の観点で圧倒的に優れている。**

今回の検討を通じて、  
「ログ量が多い環境では、リアルタイム性よりも安定性を優先すべき」  
という設計判断の重要性を再確認した。

---

## Links

- CloudWatch Logs Insights  
- AWS DevOps Agent Integration Notes  
- Internal Architecture Discussion (2026-09)

---