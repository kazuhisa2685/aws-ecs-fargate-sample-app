"""
SendMsgLambda
=================================================================
CloudWatch Alarmの通知を受け、CloudWatch Logs Insightsで過去10分間の
エラーログを取得・整形し、後続の CallDevopsAgent を呼び出す。

処理フロー:
    1. CloudWatch Alarmからの通知(Event)を受け取る
    2. ログ遅延を考慮して 60秒 待機する
    3. Insight_query.csv からアラーム名に対応する
       「ロググループ名」と「CW Insightsクエリ文」を取得する
    4. CloudWatch Logs Insights で過去10分間のログを取得・整形する
    5. 整形結果を {"message": ...} のJSON形式で CallDevopsAgent に
       Invoke する
=================================================================
"""

import csv
import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
import urllib.request

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------
# 設定値（環境変数で上書き可能。未設定時はデフォルト値を使用）
# ---------------------------------------------------------------
# Insight_query.csv の配置場所
#   - Lambdaデプロイパッケージに同梱する場合: このファイルと同じディレクトリ
#   - Lambda Layerに配置する場合: /opt/Insight_query.csv 等を環境変数で指定
CSV_FILE_PATH = os.environ.get(
    "INSIGHT_QUERY_CSV_PATH",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "Insight_query.csv"),
)
CSV_DELIMITER = "%"

# 後続Lambda(CallDevopsAgent)の関数名・呼び出し方式
DOWNSTREAM_LAMBDA_NAME = os.environ.get("CALL_DEVOPS_AGNT_LAMBDA_NAME", "CallDevopsAgent")
# "Event" = 非同期呼び出し / "RequestResponse" = 同期呼び出し
INVOCATION_TYPE = os.environ.get("INVOCATION_TYPE", "Event")

# ログ遅延対策の待機秒数（要件により固定60秒だが、検証用に環境変数で変更可能にしておく）
WAIT_SECONDS_BEFORE_QUERY = int(os.environ.get("WAIT_SECONDS_BEFORE_QUERY", "60"))
# クエリ対象期間（分）
LOOKBACK_MINUTES = int(os.environ.get("LOOKBACK_MINUTES", "10"))

# Logs Insightsクエリのポーリング設定
QUERY_POLL_INTERVAL_SECONDS = float(os.environ.get("QUERY_POLL_INTERVAL_SECONDS", "2"))
QUERY_TIMEOUT_SECONDS = int(os.environ.get("QUERY_TIMEOUT_SECONDS", "60"))

# 後続Lambdaへ渡すmessageの最大文字数（Payload肥大化防止。Lambda同期呼び出しは6MB上限）
MAX_MESSAGE_LENGTH = int(os.environ.get("MAX_MESSAGE_LENGTH", "50000"))

logs_client = boto3.client("logs")
lambda_client = boto3.client("lambda")

SLACK_WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]


# =================================================================
# 例外定義
# =================================================================
class AlarmMappingNotFoundError(Exception):
    """CSVマッピングに該当するアラーム名が見つからない場合の例外"""


class InsightsQueryError(Exception):
    """CloudWatch Logs Insightsクエリの実行・取得に失敗した場合の例外"""


# =================================================================
# 1. CloudWatch Alarmイベントからアラーム名を抽出
# =================================================================
def extract_alarm_name(event):
    """
    CloudWatch Alarmの通知イベントからアラーム名を抽出する。

    以下3パターンに対応:
      - SNS経由 (Records[0].Sns.Message 内のJSONに AlarmName)
      - EventBridge経由 (detail.alarmName)
      - テスト用に直接 {"AlarmName": "..."} が渡された場合
    """
    try:
        if isinstance(event, dict) and "Records" in event:
            logger.info("SNS経由のイベントを検出しました。")
            record = event["Records"][0]
            sns_message_raw = record.get("Sns", {}).get("Message")
            if sns_message_raw:
                sns_message = json.loads(sns_message_raw)
                alarm_name = sns_message.get("AlarmName")
                if alarm_name:
                    return alarm_name

        if isinstance(event, dict) and "detail" in event:
            logger.info("EventBridge経由のイベントを検出しました。")
            detail = event.get("detail", {}) or {}
            alarm_name = detail.get("alarmName") or detail.get("AlarmName")
            if alarm_name:
                return alarm_name

        if isinstance(event, dict):
            logger.info("直接呼び出しを検出しました。")
            alarm_name = event.get("AlarmName") or event.get("alarmName")
            if alarm_name:
                return alarm_name

    except (json.JSONDecodeError, IndexError, KeyError, TypeError) as e:
        logger.error("アラームイベントの解析に失敗しました: %s", e)

    raise ValueError(
        "イベントからアラーム名(AlarmName)を抽出できませんでした。 "
        "event={}".format(json.dumps(event, default=str, ensure_ascii=False))
    )


# =================================================================
# 2. Insight_query.csv のロード・検索
# =================================================================
def load_alarm_mapping(csv_path):
    """
    Insight_query.csv (区切り文字 '%') を読み込み、
    { アラーム名: {"log_group_name": ..., "query_string": ...} } の
    dict を返す。
    """
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"マッピングCSVファイルが見つかりません: {csv_path}")

    mapping = {}
    with open(csv_path, mode="r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f, delimiter=CSV_DELIMITER)
        for line_no, row in enumerate(reader, start=1):
            if not row or all(not c.strip() for c in row):
                continue  # 空行はスキップ
            if row[0].strip().startswith("#"):
                continue  # '#'始まりの行はコメントとしてスキップ
            if len(row) != 3:
                logger.warning(
                    "Insight_query.csv %d行目のフォーマットが不正です(3列必須): %s",
                    line_no, row,
                )
                continue

            alarm_name, log_group_name, query_string = (c.strip() for c in row)
            mapping[alarm_name] = {
                "log_group_name": log_group_name,
                "query_string": query_string,
            }

    return mapping


def find_mapping_for_alarm(alarm_name, mapping):
    """アラーム名に対応する (ロググループ名, クエリ文) を返す。見つからなければ例外。"""
    entry = mapping.get(alarm_name)
    if entry is None:
        raise AlarmMappingNotFoundError(
            f"アラーム名 '{alarm_name}' に対応するマッピングが "
            f"Insight_query.csv 内に見つかりません。"
        )
    return entry["log_group_name"], entry["query_string"]


# =================================================================
# 3. CloudWatch Logs Insights クエリ実行（非同期 start_query → ポーリング）
# =================================================================
def run_insights_query(log_group_name, query_string, lookback_minutes):
    """
    指定ロググループに対し、過去 lookback_minutes 分間の Logs Insights
    クエリを実行し、結果 (results形式のリスト) を返す。
    """
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(minutes=lookback_minutes)

    try:
        start_response = logs_client.start_query(
            logGroupName=log_group_name,
            startTime=int(start_time.timestamp()),
            endTime=int(end_time.timestamp()),
            queryString=query_string,
        )
    except logs_client.exceptions.ResourceNotFoundException as e:
        raise InsightsQueryError(
            f"ロググループが見つかりません: {log_group_name} ({e})"
        ) from e
    except Exception as e:  # noqa: BLE001 - Insights起動失敗を包括的にハンドリング
        raise InsightsQueryError(f"Logs Insightsクエリの開始に失敗しました: {e}") from e

    query_id = start_response["queryId"]
    logger.info(
        "Logs Insightsクエリを開始しました。queryId=%s, logGroup=%s",
        query_id, log_group_name,
    )

    elapsed = 0.0
    status = "Running"
    results = []

    while elapsed < QUERY_TIMEOUT_SECONDS:
        time.sleep(QUERY_POLL_INTERVAL_SECONDS)
        elapsed += QUERY_POLL_INTERVAL_SECONDS

        try:
            response = logs_client.get_query_results(queryId=query_id)
        except Exception as e:  # noqa: BLE001
            raise InsightsQueryError(
                f"クエリ結果の取得に失敗しました(queryId={query_id}): {e}"
            ) from e

        status = response.get("status")
        if status in ("Complete", "Failed", "Cancelled", "Timeout"):
            results = response.get("results", [])
            break

        logger.info("クエリ実行中... status=%s, 経過時間=%.1f秒", status, elapsed)
    else:
        # while-elseはbreakせずループを抜けた場合(タイムアウト)に実行される
        try:
            logs_client.stop_query(queryId=query_id)
        except Exception:  # noqa: BLE001 - stop失敗は握りつぶしてタイムアウト例外を優先
            pass
        raise InsightsQueryError(
            f"クエリがタイムアウトしました(queryId={query_id}, "
            f"timeout={QUERY_TIMEOUT_SECONDS}秒)"
        )

    if status != "Complete":
        raise InsightsQueryError(
            f"クエリが正常終了しませんでした。queryId={query_id}, status={status}"
        )

    logger.info("Logs Insightsクエリが完了しました。取得件数=%d", len(results))
    return results


# =================================================================
# 4. クエリ結果の整形（後続Lambdaへ渡す1本のテキストに変換）
# =================================================================
def format_query_results(results, alarm_name, log_group_name):
    """
    get_query_results() の results (List[List[{"field":..,"value":..}]]) を
    後続Lambdaへ渡すための単一のテキストに整形する。

    JSON化時のパースエラーを避けるため、ここでは通常の文字列として組み立て、
    最終的な送信時に json.dumps でまとめてエスケープする(=改行や引用符は
    json.dumps が自動的に \\n や \\" にエスケープするため、ここで個別に
    手動エスケープする必要はない)。
    """
    if not results:
        body = "(該当期間内にエラーログは見つかりませんでした)"
    else:
        lines = []
        for row in results:
            field_map = {f["field"]: f["value"] for f in row}
            timestamp = field_map.pop("@timestamp", "")
            message = field_map.pop("@message", "")
            # CRLFはLFに正規化し、後続処理での不整合を防ぐ
            message = message.replace("\r\n", "\n").strip()

            extra_fields = ", ".join(
                f"{k}={v}" for k, v in field_map.items() if not k.startswith("@")
            )

            line = f"[{timestamp}] {message}"
            if extra_fields:
                line += f" ({extra_fields})"
            lines.append(line)

        body = "\n".join(lines)

    # 過大なペイロードを防ぐため、必要に応じて切り詰める
    if len(body) > MAX_MESSAGE_LENGTH:
        omitted = len(body) - MAX_MESSAGE_LENGTH
        body = body[:MAX_MESSAGE_LENGTH] + f"\n...(以下 {omitted} 文字省略)"

    header = (
        f"[アラーム名] {alarm_name}\n"
        f"[ロググループ] {log_group_name}\n"
        f"[対象期間] 過去{LOOKBACK_MINUTES}分間\n"
        f"[検出件数] {len(results)}件\n"
        f"----------------------------------------\n"
    )
    return header + body


# =================================================================
# 5. 後続Lambda(CallDevopsAgent)呼び出し
# =================================================================
def invoke_downstream_lambda(message_text, extra_context=None):
    """
    整形済みメッセージを {"message": message_text, ...} のJSONとして
    CallDevopsAgent へ Invoke する。

    - ルートキーに必ず "message" を含める(後続Lambdaの必須仕様)
    - json.dumps でエンコードすることで改行・特殊文字は自動的に
      安全にエスケープされ、パースエラーを防止する
    """
    payload = {"message": message_text}
    if extra_context:
        payload.update(extra_context)

    try:
        # ensure_ascii=False: 日本語ログ等をそのままUTF-8で送る(サイズ削減)
        payload_bytes = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    except (TypeError, ValueError) as e:
        raise ValueError(f"payloadのJSONシリアライズに失敗しました: {e}") from e

    try:
        response = lambda_client.invoke(
            FunctionName=DOWNSTREAM_LAMBDA_NAME,
            InvocationType=INVOCATION_TYPE,  # "Event"=非同期 / "RequestResponse"=同期
            Payload=payload_bytes,
        )
    except Exception as e:  # noqa: BLE001
        raise RuntimeError(
            f"後続Lambda({DOWNSTREAM_LAMBDA_NAME})の呼び出しに失敗しました: {e}"
        ) from e

    status_code = response.get("StatusCode")
    logger.info(
        "後続Lambda呼び出し完了。FunctionName=%s, InvocationType=%s, StatusCode=%s",
        DOWNSTREAM_LAMBDA_NAME, INVOCATION_TYPE, status_code,
    )

    # 同期呼び出し時のみレスポンスPayloadを解析して返す
    if INVOCATION_TYPE == "RequestResponse":
        resp_payload_raw = response["Payload"].read()
        try:
            resp_payload = json.loads(resp_payload_raw)
        except json.JSONDecodeError:
            resp_payload = resp_payload_raw.decode("utf-8", errors="replace")

        if response.get("FunctionError"):
            logger.error("後続Lambda実行時にエラーが発生しました: %s", resp_payload)

        return resp_payload

    return {"StatusCode": status_code}


# =================================================================
# Lambda エントリポイント
# =================================================================
def lambda_handler(event, context):
    logger.info("SendMsgLambda 起動。event=%s", json.dumps(event, default=str, ensure_ascii=False))

    # --- 1. アラーム名の抽出 -------------------------------------
    try:
        alarm_name = extract_alarm_name(event)
    except ValueError as e:
        logger.error(str(e))
        return {"statusCode": 400, "body": f"アラーム情報の解析に失敗しました: {e}"}

    logger.info("受信アラーム名: %s", alarm_name)

    # --- 2. ログ遅延対策の待機 ------------------------------------
    # 発生直後のログ遅延を考慮し、直近10分間のエラーログを漏れなく
    # 確実に収集するために60秒待機する
    logger.info("%d秒待機します(ログ遅延考慮)...", WAIT_SECONDS_BEFORE_QUERY)
    #time.sleep(WAIT_SECONDS_BEFORE_QUERY)

    # --- 3. CSVマッピングのロード・該当行検索 ----------------------
    try:
        mapping = load_alarm_mapping(CSV_FILE_PATH)
        log_group_name, query_string = find_mapping_for_alarm(alarm_name, mapping)
    except FileNotFoundError as e:
        logger.error(str(e))
        return {"statusCode": 500, "body": str(e)}
    except AlarmMappingNotFoundError as e:
        logger.error(str(e))
        return {"statusCode": 404, "body": str(e)}

    logger.info(
        "マッピング取得成功。logGroup=%s, query=%s",
        log_group_name, query_string,
    )

    # --- 4. CloudWatch Logs Insights クエリ実行 ---------------------
    try:
        results = run_insights_query(log_group_name, query_string, LOOKBACK_MINUTES)
    except InsightsQueryError as e:
        logger.error(str(e))
        return {"statusCode": 500, "body": str(e)}

    # --- 5. 結果整形 ------------------------------------------------
    message_text = format_query_results(results, alarm_name, log_group_name)
    logger.info("message_text:" + message_text)

    # --- 6. 即時通知 ------------------------------------------------
    payload = {"text": message_text}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        SLACK_WEBHOOK_URL, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as res:
        logger.info(f"Slack notification sent: {res.status}")

    # --- 7. 後続Lambda(CallDevopsAgent)へ連携 --------------------
    try:
        invoke_result = invoke_downstream_lambda(
            message_text,
            extra_context={
                "alarm_name": alarm_name,
                "log_group": log_group_name,
                "error_count": len(results),
            },
        )
    except (RuntimeError, ValueError) as e:
        logger.error(str(e))
        return {"statusCode": 500, "body": str(e)}

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "alarm_name": alarm_name,
                "log_group": log_group_name,
                "error_count": len(results),
                "downstream_invoke_result": invoke_result,
            },
            ensure_ascii=False,
            default=str,
        ),
    }
