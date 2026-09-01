"""TTS endpoint: ElevenLabs when configured, explicit fallback otherwise.

The Flutter client calls POST /api/v1/tts with text and plays the returned
audio. If ElevenLabs is not configured (or fails) the endpoint returns 503 and
the client falls back to on-device TTS.
"""

import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field

from ...core.config import settings
from ...core.security import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()


class TTSRequest(BaseModel):
    text: str = Field(min_length=1, max_length=1200)
    voice: str = Field(default="female", pattern="^(male|female)$")


@router.post("/tts")
def synthesize_speech(
    request: TTSRequest,
    current_user=Depends(get_current_user),
):
    """Return audio/mpeg from ElevenLabs, or 503 so the client uses local TTS."""
    if not settings.ELEVENLABS_API_KEY:
        raise HTTPException(status_code=503, detail="TTS provider not configured")

    voice_id = settings.ELEVENLABS_VOICE_ID
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    payload = {
        "text": request.text,
        "model_id": settings.ELEVENLABS_MODEL,
        "voice_settings": {
            "stability": 0.55,
            "similarity_boost": 0.75,
            # Slightly lower pitch via style is not supported; gender is handled
            # by choosing the voice id in ELEVENLABS_VOICE_ID.
        },
    }
    try:
        response = httpx.post(
            url,
            json=payload,
            headers={"xi-api-key": settings.ELEVENLABS_API_KEY},
            params={"output_format": "mp3_44100_128"},
            timeout=30.0,
        )
        response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        logger.warning("ElevenLabs TTS failed with %s", exc.response.status_code)
        raise HTTPException(status_code=503, detail="TTS provider error") from exc
    except httpx.HTTPError as exc:
        logger.warning("ElevenLabs TTS unreachable: %s", exc)
        raise HTTPException(status_code=503, detail="TTS provider unreachable") from exc

    return Response(content=response.content, media_type="audio/mpeg")
