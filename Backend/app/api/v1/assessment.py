"""Level assessment endpoints for reading and speaking feedback."""
import json
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...ai.providers.factory import create_text_provider
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
    try:
        provider = create_text_provider()
        generated = provider.generate_text(
            system_prompt="You are an English assessment examiner. Return valid JSON only.",
            user_prompt=instruction,
            temperature=0.1,
            json_mode=True,
        )
        if generated is None:
            return None
        content = generated.value
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
