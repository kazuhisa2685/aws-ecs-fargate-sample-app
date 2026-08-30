from datetime import datetime
from pydantic import BaseModel, ConfigDict


class MemoCreate(BaseModel):
    title: str
    content: str | None = None


class MemoOut(BaseModel):
    id: int
    title: str
    content: str | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
