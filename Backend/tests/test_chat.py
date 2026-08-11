"""
Tests for chat endpoint.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.api.v1.chat import ChatMessage, chat
from app.core.config import settings
from app.core.database import Base


# إعداد قاعدة بيانات وهمية للاختبار
@pytest.fixture
def test_db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    
    yield db
    
    db.close()
    Base.metadata.drop_all(bind=engine)


@pytest.mark.asyncio
async def test_chat_falls_back_when_openai_key_missing(monkeypatch, test_db):
    monkeypatch.setattr(settings, "OPENAI_API_KEY", "")

    response = await chat(
        ChatMessage(message="I am go to school", user_id="user123"),
        db=test_db,
    )

    assert response.reply
    assert response.corrections
    assert response.corrections[0]["correct"] == "I am going"
    assert response.tips