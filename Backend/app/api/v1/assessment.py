"""Level assessment endpoints for reading and speaking feedback."""
import json
from typing import List

import httpx
from fastapi import APIRouter, Depends, HTTPException
from openai import OpenAI
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.config import settings
from ...core.database import get_db
from ...models.user import User
from ...core.security import enforce_owner, get_current_user

router = APIRouter()


class ReadingRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=120)
    passage: str = Field(min_length=20, max_length=5000)
    answer: str = Field(min_length=1, max_length=1000)


class SpeakingRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=120)
    prompt: str = Field(min_length=3, max_length=500)
    transcript: str = Field(min_length=3, max_length=5000)


class LevelResultRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=120)
    level: str = Field(min_length=2, max_length=10)
    score: int = Field(ge=0, le=100)


def _ai_json(instruction: str) -> dict | None:
    provider = settings.AI_TEXT_PROVIDER.strip().lower()
    try:
        if provider == "gemini":
            if not settings.GEMINI_API_KEY:
                return None
            response = httpx.post(
                "https://generativelanguage.googleapis.com/v1beta/models/"
                f"{settings.GEMINI_MODEL}:generateContent",
                params={"key": settings.GEMINI_API_KEY},
                json={
                    "contents": [{"role": "user", "parts": [{"text": instruction}]}],
                    "generationConfig": {
                        "temperature": 0.1,
                        "maxOutputTokens": 500,
                        "responseMimeType": "application/json",
                    },
                },
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()
            candidates = data.get("candidates") or []
            parts = ((candidates[0].get("content") or {}).get("parts") or []) if candidates else []
            content = "".join(str(part.get("text", "")) for part in parts).strip()
        else:
            if not settings.OPENAI_API_KEY:
                return None
            client = OpenAI(api_key=settings.OPENAI_API_KEY, base_url=settings.OPENAI_BASE_URL)
            response = client.chat.completions.create(
                model=settings.OPENAI_MODEL,
                messages=[
                    {"role": "system", "content": "You are an English assessment examiner. Return valid JSON only."},
                    {"role": "user", "content": instruction},
                ],
                temperature=0.1,
                max_tokens=500,
                response_format={"type": "json_object"},
            )
            content = response.choices[0].message.content or "{}"

        content = content.replace("```json", "").replace("```", "").strip()
        return json.loads(content) if content else None
    except Exception as exc:
        print(f"AI assessment provider error: {exc}")
        return None


@router.post("/assessment/reading")
def assess_reading(request: ReadingRequest, current_user: User = Depends(get_current_user)):
    enforce_owner(request.user_id, current_user)
    result = _ai_json(f"""Assess this English reading answer.
Passage: {request.passage}
Answer: {request.answer}
Return JSON with keys: score (0-100), level (A1/A2/B1/B2/C1), feedback (Arabic), difficult_words (array of strings), pronunciation_help (array of objects with word and pronunciation).""")
    if result is not None:
        return result
    return {"score": 0, "level": "pending", "feedback": "تحليل القراءة يحتاج تشغيل AI Backend.", "difficult_words": [], "pronunciation_help": []}


@router.post("/assessment/speaking")
def assess_speaking(request: SpeakingRequest, current_user: User = Depends(get_current_user)):
    enforce_owner(request.user_id, current_user)
    result = _ai_json(f"""Assess this English speaking transcript.
Prompt: {request.prompt}
Transcript: {request.transcript}
Return JSON with keys: estimated_level (A1/A2/B1/B2/C1), overall_score (0-100), grammar_score, vocabulary_score, fluency_score, sentence_structure_score, naturalness_score, feedback (Arabic), corrections (array with wrong, correct, explanation). Do not claim to assess pronunciation from text alone; set pronunciation_note accordingly.""")
    if result is not None:
        return result
    return {"estimated_level": "pending", "overall_score": 0, "feedback": "تحليل التحدث يحتاج تشغيل AI Backend.", "corrections": [], "pronunciation_note": "لا يمكن تقييم النطق من النص وحده."}


@router.post("/assessment/level")
def save_level_result(request: LevelResultRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    enforce_owner(request.user_id, current_user)
    user = db.query(User).filter(User.user_id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.level = request.level
    user.level_score = request.score
    db.commit()
    return {"user_id": user.user_id, "level": user.level, "level_score": user.level_score}
