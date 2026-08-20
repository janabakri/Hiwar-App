"""Level assessment endpoints for reading and speaking feedback."""
import json
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from openai import OpenAI
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.config import settings
from ...core.database import get_db
from ...models.user import User

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


def _ai_json(instruction: str, schema_name: str, schema: dict) -> dict | None:
    if not settings.OPENAI_API_KEY:
        return None
    try:
        client = OpenAI(api_key=settings.OPENAI_API_KEY, base_url=settings.OPENAI_BASE_URL)
        response = client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=[
                {"role": "system", "content": "You are an English assessment examiner. Return valid JSON only."},
                {"role": "user", "content": instruction},
            ],
            response_format={
                "type": "json_schema",
                "json_schema": {
                    "name": schema_name,
                    "strict": True,
                    "schema": schema,
                },
            },
            temperature=0.1,
            max_tokens=500,
        )
        content = response.choices[0].message.content or "{}"
        content = content.replace("```json", "").replace("```", "").strip()
        return json.loads(content)
    except Exception:
        return None


@router.post("/assessment/reading")
def assess_reading(request: ReadingRequest):
    result = _ai_json(
        f"""Assess this English reading answer.
Passage: {request.passage}
Answer: {request.answer}""",
        "reading_assessment",
        {
            "type": "object",
            "properties": {
                "score": {"type": "integer", "minimum": 0, "maximum": 100},
                "level": {"type": "string", "enum": ["A1", "A2", "B1", "B2", "C1"]},
                "feedback": {"type": "string"},
                "difficult_words": {"type": "array", "items": {"type": "string"}},
                "pronunciation_help": {"type": "array", "items": {"type": "object", "properties": {"word": {"type": "string"}, "pronunciation": {"type": "string"}}, "required": ["word", "pronunciation"], "additionalProperties": False}},
            },
            "required": ["score", "level", "feedback", "difficult_words", "pronunciation_help"],
            "additionalProperties": False,
        },
    )
    if result is not None:
        return result
    return {"score": 0, "level": "pending", "feedback": "تحليل القراءة يحتاج تشغيل AI Backend.", "difficult_words": [], "pronunciation_help": []}


@router.post("/assessment/speaking")
def assess_speaking(request: SpeakingRequest):
    result = _ai_json(
        f"""Assess this English speaking transcript.
Prompt: {request.prompt}
Transcript: {request.transcript}
Do not claim to assess pronunciation from text alone.""",
        "speaking_assessment",
        {
            "type": "object",
            "properties": {
                "estimated_level": {"type": "string", "enum": ["A1", "A2", "B1", "B2", "C1"]},
                "overall_score": {"type": "integer", "minimum": 0, "maximum": 100},
                "grammar_score": {"type": "integer", "minimum": 0, "maximum": 100},
                "vocabulary_score": {"type": "integer", "minimum": 0, "maximum": 100},
                "fluency_score": {"type": "integer", "minimum": 0, "maximum": 100},
                "sentence_structure_score": {"type": "integer", "minimum": 0, "maximum": 100},
                "naturalness_score": {"type": "integer", "minimum": 0, "maximum": 100},
                "feedback": {"type": "string"},
                "corrections": {"type": "array", "items": {"type": "object", "properties": {"wrong": {"type": "string"}, "correct": {"type": "string"}, "explanation": {"type": "string"}}, "required": ["wrong", "correct", "explanation"], "additionalProperties": False}},
                "pronunciation_note": {"type": "string"},
            },
            "required": ["estimated_level", "overall_score", "grammar_score", "vocabulary_score", "fluency_score", "sentence_structure_score", "naturalness_score", "feedback", "corrections", "pronunciation_note"],
            "additionalProperties": False,
        },
    )
    if result is not None:
        return result
    return {"estimated_level": "pending", "overall_score": 0, "feedback": "تحليل التحدث يحتاج تشغيل AI Backend.", "corrections": [], "pronunciation_note": "لا يمكن تقييم النطق من النص وحده."}


@router.post("/assessment/level")
def save_level_result(request: LevelResultRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.user_id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.level = request.level
    user.level_score = request.score
    db.commit()
    return {"user_id": user.user_id, "level": user.level, "level_score": user.level_score}
