"""TTS endpoint: natural voices with graceful fallback.

Priority: ElevenLabs (if key set) → Gemini native TTS (natural voices) → 503
so the Flutter client falls back to on-device TTS.
"""

import base64
import logging
import struct

import httpx
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field

from ...core.config import settings
from ...core.security import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()

TTS_MODEL = "gemini-2.5-flash-preview-tts"
# Natural Gemini voices: female → Aoede/Kore, male → Puck/Enceladus.
_GEMINI_VOICE_BY_PREFERENCE = {"female": "Aoede", "male": "Puck"}


class TTSRequest(BaseModel):
    text: str = Field(min_length=1, max_length=1200)
    voice: str = Field(default="female", pattern="^(male|female)$")


def _pcm_to_wav(pcm: bytes, sample_rate: int = 24000, channels: int = 1, bits: int = 16) -> bytes:
    """Wrap raw signed 16-bit little-endian PCM in a RIFF/WAV header."""
    byte_rate = sample_rate * channels * bits // 8
    block_align = channels * bits // 8
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF", 36 + len(pcm), b"WAVE", b"fmt ", 16, 1, channels,
        sample_rate, byte_rate, block_align, bits, b"data", len(pcm),
    )
    return header + pcm


def _gemini_tts(text: str, voice: str) -> bytes:
    voice_name = _GEMINI_VOICE_BY_PREFERENCE.get(voice, "Aoede")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{TTS_MODEL}:generateContent"
    payload = {
        "contents": [{"parts": [{"text": text}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice_name}}},
        },
    }
    response = httpx.post(url, params={"key": settings.GEMINI_API_KEY}, json=payload, timeout=60.0)
    response.raise_for_status()
    parts = response.json().get("candidates", [{}])[0].get("content", {}).get("parts", [])
    inline = next((p.get("inlineData") for p in parts if p.get("inlineData")), None)
    if not inline or not inline.get("data"):
        raise RuntimeError("Gemini TTS returned no audio")
    return _pcm_to_wav(base64.b64decode(inline["data"]))


def _elevenlabs_tts(text: str, voice: str) -> bytes:
    voice_id = settings.ELEVENLABS_VOICE_ID
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    payload = {
        "text": text,
        "model_id": settings.ELEVENLABS_MODEL,
        "voice_settings": {"stability": 0.55, "similarity_boost": 0.75},
    }
    response = httpx.post(
        url,
        json=payload,
        headers={"xi-api-key": settings.ELEVENLABS_API_KEY},
        params={"output_format": "mp3_44100_128"},
        timeout=60.0,
    )
    response.raise_for_status()
    return response.content


@router.post("/tts")
def synthesize_speech(
    request: TTSRequest,
    current_user=Depends(get_current_user),
):
    """Natural tutor voice; 503 lets the client use on-device TTS."""
    if settings.ELEVENLABS_API_KEY:
        try:
            return Response(content=_elevenlabs_tts(request.text, request.voice), media_type="audio/mpeg")
        except Exception as exc:  # noqa: BLE001
            logger.warning("ElevenLabs TTS failed: %s", exc)

    if settings.GEMINI_API_KEY:
        try:
            return Response(content=_gemini_tts(request.text, request.voice), media_type="audio/wav")
        except Exception as exc:  # noqa: BLE001
            logger.warning("Gemini TTS failed: %s", exc)

    raise HTTPException(status_code=503, detail="TTS providers unavailable")
