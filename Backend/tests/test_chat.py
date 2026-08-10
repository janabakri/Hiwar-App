import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.api.v1.chat import ChatMessage, chat
from app.core.config import settings


@pytest.mark.asyncio
async def test_chat_falls_back_when_openai_key_missing(monkeypatch):
    monkeypatch.setattr(settings, "OPENAI_API_KEY", "")

    response = await chat(
        ChatMessage(message="I am go to school", user_id="user123"),
        db=None,
    )

    assert response.reply
    assert response.corrections
    assert response.corrections[0]["correct"] == "I am going"
    assert response.tips
