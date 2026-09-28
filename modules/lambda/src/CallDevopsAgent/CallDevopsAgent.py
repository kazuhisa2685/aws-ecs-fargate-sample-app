import os
import json
import uuid
import boto3
import logging
import urllib.request

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logging.basicConfig(level=logging.INFO)

AGENT_SPACE_ID = os.environ["DEVOPS_AGENT_SPACE_ID"]
SLACK_WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]

client = boto3.client("devops-agent")


def send_slack(text):
    """Slack Incoming Webhook へ直接投稿する関数"""
    payload = {"text": text}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        SLACK_WEBHOOK_URL, data=data, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as res:
            logger.info(f"Slack notification sent: {res.status}")
            return True
    except Exception as e:
        logger.error(f"Failed to send Slack notification: {e}")
        return False


def lambda_handler(event, context):
    message = event.get("message") or event.get("error_message")
    logger.info(f"Message: {message}")
    
    if not message:
        return {"statusCode": 400, "body": "message (or error_message) is required"}

    # 1. チャットセッション作成
    chat = client.create_chat(agentSpaceId=AGENT_SPACE_ID)
    execution_id = chat["executionId"]

    # 2. メッセージ送信
    prompt = (
        "以下のエラーメッセージについて調査・分析してください。"
        "考えられる原因、影響範囲、対処方法を教えてください。\n\n"
        "ただし、回答は4000文字以内としてください。"
        f"{message}"
    )

    response = client.send_message(
        agentSpaceId=AGENT_SPACE_ID,
        executionId=execution_id,
        content=prompt,
    )

    # 3. テキスト組み立て
    answer_chunks = []
    error_info = None

    for evt in response["events"]:
        if "contentBlockDelta" in evt:
            delta = evt["contentBlockDelta"]["delta"]
            text = delta.get("textDelta", {}).get("text")
            if text:
                answer_chunks.append(text)
        elif "responseFailed" in evt:
            error_info = evt["responseFailed"]
            break
        elif "responseCompleted" in evt:
            break

    if error_info:
        slack_error_msg = f"*DevOps Agent エラー*\n*実行ID:* `{execution_id}`\n\n```\n{error_info}\n```"
        send_slack(slack_error_msg)
        return {"statusCode": 500, "body": slack_error_msg}

    raw_answer = "".join(answer_chunks)
    cleaned_answer = raw_answer.replace("\\n", "\n")

    # Slack 用に見やすくマークダウン整形
    slack_msg = f"*DevOps Agent 分析結果報告*\n*実行ID:* `{execution_id}`\n\n{cleaned_answer}"

    # Slack へ直接通知
    send_slack(slack_msg)

    return {"statusCode": 200, "body": slack_msg}