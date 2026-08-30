from sqlalchemy import Column, Integer, String, DateTime, func
from .database import Base


class Memo(Base):
    """練習用のシンプルなメモモデル"""

    __tablename__ = "memos"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(100), nullable=False)
    content = Column(String(1000), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
