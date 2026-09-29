"""Shared pytest fixtures.

Resets the in-memory rate limiter before every test so requests made by
earlier tests never consume the auth/general quota of later ones.
"""

from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings
from app.core.rate_limit import limiter


@pytest.fixture(autouse=True)
def _no_real_ai_providers(monkeypatch):
    """Never reach real AI/TTS/email services with the settings from .env: that
    is slow, needs internet, burns the daily quota and can send real emails.
    Tests that need an AI reply stub it themselves (see `fake_gemini` in
    test_chat_ai_memory.py)."""
    for key in ("GEMINI_API_KEY", "OPENAI_API_KEY", "ELEVENLABS_API_KEY", "AZURE_SPEECH_KEY", "SMTP_HOST"):
        monkeypatch.setattr(settings, key, "")


@pytest.fixture(autouse=True)
def _reset_rate_limiter():
    limiter._hits.clear()
    yield
    limiter._hits.clear()
