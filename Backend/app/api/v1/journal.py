"""Daily English journal endpoints linked to speaking practice."""
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.database import get_db
from ...core.security import enforce_owner, get_current_user
from ...models.journal import JournalEntry
from ...models.user import User
from .chat import _generate_gemini, _parse_json_object

router = APIRouter()


class JournalAnalyzeRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=50)
    text: str = Field(min_length=2, max_length=1000)


class JournalAnalyzeResponse(BaseModel):
    id: int
    original_text: str
    corrected_text: str
    follow_up_question: str
    corrections: List[dict]


@router.post("/journal/analyze", response_model=JournalAnalyzeResponse)
def analyze_journal(
    request: JournalAnalyzeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    enforce_owner(request.user_id, current_user)
    prompt = f"""
You are a careful English tutor for an Arabic-speaking learner.
Analyze this short daily journal entry without inventing mistakes.
Return JSON with exactly these keys:
- reply: one natural follow-up speaking question based on the entry
- corrections: an array of objects with wrong, correct, explanation; include only real corrections
- tips: an array whose first item is the corrected full entry, and whose second item is a short natural version if useful
Keep the language encouraging and do not claim a level.
Journal entry: {request.text.strip()}
"""
    try:
        parsed = _parse_json_object(_generate_gemini(prompt))
    except Exception as exc:
        raise HTTPException(status_code=503, detail="تعذر تحليل اليومية. تأكد من إعداد مزود الذكاء الاصطناعي في Backend.") from exc

    corrections = parsed.get("corrections") if isinstance(parsed.get("corrections"), list) else []
    tips = parsed.get("tips") if isinstance(parsed.get("tips"), list) else []
    corrected_text = str(tips[0]).strip() if tips and str(tips[0]).strip() else request.text.strip()
    question = str(parsed.get("reply") or "What happened next?").strip()
    entry = JournalEntry(
        user_id=current_user.id,
        original_text=request.text.strip(),
        corrected_text=corrected_text,
        follow_up_question=question,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return JournalAnalyzeResponse(
        id=entry.id,
        original_text=entry.original_text,
        corrected_text=entry.corrected_text,
        follow_up_question=entry.follow_up_question,
        corrections=[item for item in corrections if isinstance(item, dict)],
    )


@router.get("/journal/{user_id}")
def list_journal(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    enforce_owner(user_id, current_user)
    entries = db.query(JournalEntry).filter(JournalEntry.user_id == current_user.id).order_by(JournalEntry.created_at.desc()).limit(30).all()
    return {
        "entries": [
            {
                "id": item.id,
                "original_text": item.original_text,
                "corrected_text": item.corrected_text,
                "follow_up_question": item.follow_up_question,
                "created_at": item.created_at.isoformat() if item.created_at else None,
            }
            for item in entries
        ]
    }
