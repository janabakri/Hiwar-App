"""Past conversations, smart suggestions and spaced-repetition review."""

import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.database import get_db
from ...core.security import enforce_owner, get_current_user
from ...models.user import User
from ...models.error import UserError
from ...models.conversation import Conversation, Message

logger = logging.getLogger(__name__)
router = APIRouter()


def _resolve_user(requested_user_id: str, current_user: User | None, db: Session) -> User:
    if isinstance(current_user, User):
        enforce_owner(requested_user_id, current_user)
        return current_user
    user = db.query(User).filter(User.user_id == requested_user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ---------------- Past conversations ----------------

@router.get("/conversations/{user_id}")
def list_conversations(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """List the learner's conversations with a short preview of each."""
    user = _resolve_user(user_id, current_user, db)
    conversations = (
        db.query(Conversation)
        .filter(Conversation.user_id == user.id)
        .order_by(Conversation.updated_at.desc())
        .limit(50)
        .all()
    )
    items = []
    for conversation in conversations:
        first_user_message = (
            db.query(Message)
            .filter(Message.conversation_id == conversation.id, Message.role == "user")
            .order_by(Message.created_at.asc())
            .first()
        )
        message_count = db.query(Message).filter(Message.conversation_id == conversation.id).count()
        items.append({
            "conversation_id": conversation.id,
            "title": (first_user_message.content[:80] if first_user_message else "محادثة"),
            "message_count": message_count,
            "updated_at": conversation.updated_at.isoformat(),
        })
    return {"user_id": user_id, "conversations": items}


@router.get("/conversations/{user_id}/{conversation_id}")
def get_conversation(
    user_id: str,
    conversation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """Full message history for one conversation (owned by the learner)."""
    user = _resolve_user(user_id, current_user, db)
    conversation = (
        db.query(Conversation)
        .filter(Conversation.id == conversation_id, Conversation.user_id == user.id)
        .first()
    )
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    messages = (
        db.query(Message)
        .filter(Message.conversation_id == conversation.id)
        .order_by(Message.created_at.asc())
        .all()
    )
    return {
        "conversation_id": conversation.id,
        "created_at": conversation.created_at.isoformat(),
        "updated_at": conversation.updated_at.isoformat(),
        "messages": [
            {"id": m.id, "role": m.role, "content": m.content, "created_at": m.created_at.isoformat()}
            for m in messages
        ],
    }



# ---------------- Smart weekly suggestion ----------------

@router.get("/suggestion/{user_id}")
def smart_suggestion(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """A weekly focus suggestion derived from the learner's real repeated errors."""
    user = _resolve_user(user_id, current_user, db)
    top_errors: List[UserError] = (
        db.query(UserError)
        .filter(UserError.user_id == user.id, UserError.mastered == False)  # noqa: E712
        .order_by(UserError.count.desc(), UserError.last_occurrence.desc())
        .limit(2)
        .all()
    )
    if not top_errors:
        return {
            "has_suggestion": False,
            "text": "ابدأ أول محادثة صوتية وخلّنا نبني اقتراحك على كلامك الحقيقي.",
            "focus": [],
        }
    focus_labels = []
    parts = []
    for error in top_errors:
        if error.error_type == "grammar":
            focus_labels.append("قواعد")
        elif error.error_type == "vocabulary":
            focus_labels.append("مفردات")
        else:
            focus_labels.append(error.error_type)
        parts.append(f"«{error.wrong_text}» ← «{error.correct_text}»")
    text = (
        f"بناءً على محادثاتك، ركّز هالأسبوع على {' و'.join(dict.fromkeys(focus_labels))} — "
        f"أكثر ملاحظة متكررة عندك: {' و'.join(parts)}."
    )
    return {"has_suggestion": True, "text": text, "focus": focus_labels}


# ---------------- Spaced repetition review ----------------

# Simple SM-2-like intervals in days, indexed by review stage (error.count).
_REVIEW_INTERVALS_DAYS = [1, 3, 7, 14]


def _is_due(error: UserError, now: datetime) -> bool:
    last = error.last_occurrence or error.created_at or now
    stage = min(error.count, len(_REVIEW_INTERVALS_DAYS)) - 1
    interval = _REVIEW_INTERVALS_DAYS[max(stage, 0)]
    return now - last >= timedelta(days=interval)


@router.get("/review/{user_id}")
def review_queue(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """Errors that are due for a spaced-repetition review session."""
    user = _resolve_user(user_id, current_user, db)
    now = datetime.utcnow()
    unmastered = (
        db.query(UserError)
        .filter(UserError.user_id == user.id, UserError.mastered == False)  # noqa: E712
        .order_by(UserError.last_occurrence.asc())
        .all()
    )
    due = [e for e in unmastered if _is_due(e, now)]
    return {
        "user_id": user_id,
        "due_count": len(due),
        "total_unmastered": len(unmastered),
        "errors": [
            {
                "id": e.id,
                "wrong": e.wrong_text,
                "correct": e.correct_text,
                "explanation": e.explanation,
                "error_type": e.error_type,
                "count": e.count,
                "last_occurrence": (e.last_occurrence or now).isoformat(),
            }
            for e in due[:10]
        ],
    }


class ReviewAnswer(BaseModel):
    error_id: int = Field(gt=0)
    remembered: bool = True


@router.post("/review/{user_id}/answer")
def review_answer(
    user_id: str,
    request: ReviewAnswer,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """Record a review outcome. Remembered → next interval; not → back to shortest."""
    user = _resolve_user(user_id, current_user, db)
    error = db.query(UserError).filter(
        UserError.id == request.error_id, UserError.user_id == user.id
    ).first()
    if error is None:
        raise HTTPException(status_code=404, detail="Error not found")
    if request.remembered:
        error.count = min(error.count + 1, len(_REVIEW_INTERVALS_DAYS) + 1)
        if error.count > len(_REVIEW_INTERVALS_DAYS):
            error.mastered = True
    else:
        error.count = 1
    error.last_occurrence = datetime.utcnow()
    db.commit()
    return {"error_id": error.id, "mastered": bool(error.mastered), "next_stage": error.count}
