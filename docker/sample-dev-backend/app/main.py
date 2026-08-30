import logging
import os

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text

from . import models, schemas
from .database import engine, get_db, Base

# --- ロギング設定 (CloudWatch Logsへ標準出力経由で連携する想定) ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("sample-dev-backend")

app = FastAPI(title="Sample Dev Backend", version="0.1.0")

# フロントエンド(別コンテナ/別オリジン)からのアクセスを許可
FRONTEND_ORIGIN = os.getenv("FRONTEND_ORIGIN", "*")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[FRONTEND_ORIGIN] if FRONTEND_ORIGIN != "*" else ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    # 練習用: 起動時にテーブルが無ければ作成する
    # 本番運用ではAlembic等でマイグレーションを管理する想定
    Base.metadata.create_all(bind=engine)
    logger.info("Application startup complete")


@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    """ALB / ECSヘルスチェック用エンドポイント"""
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ok"}
    except Exception as e:
        logger.error(f"Health check DB error: {e}")
        raise HTTPException(status_code=503, detail="database unavailable")


@app.get("/memos", response_model=list[schemas.MemoOut])
def list_memos(db: Session = Depends(get_db)):
    return db.query(models.Memo).order_by(models.Memo.id.desc()).all()


@app.post("/memos", response_model=schemas.MemoOut, status_code=201)
def create_memo(memo: schemas.MemoCreate, db: Session = Depends(get_db)):
    db_memo = models.Memo(title=memo.title, content=memo.content)
    db.add(db_memo)
    db.commit()
    db.refresh(db_memo)
    logger.info(f"Created memo id={db_memo.id}")
    return db_memo


@app.delete("/memos/{memo_id}", status_code=204)
def delete_memo(memo_id: int, db: Session = Depends(get_db)):
    db_memo = db.query(models.Memo).filter(models.Memo.id == memo_id).first()
    if not db_memo:
        raise HTTPException(status_code=404, detail="memo not found")
    db.delete(db_memo)
    db.commit()
    logger.info(f"Deleted memo id={memo_id}")
    return None
