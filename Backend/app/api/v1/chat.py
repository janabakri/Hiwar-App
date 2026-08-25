"""
Chat API endpoints with database integration.
"""

import json
from datetime import datetime
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.database import get_db
from ...ai.providers.factory import create_text_provider
from ...services.error_tracker import detect_errors
from ...models.user import User
from ...models.error import UserError
from ...models.conversation import Conversation, Message
from ...core.security import enforce_owner, get_current_user

router = APIRouter()


def _parse_json_object(raw: str) -> dict:
    """Parse a provider JSON response even if it adds a markdown fence."""
    cleaned = raw.replace("```json", "").replace("```", "").strip()
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError:
        start, end = cleaned.find("{"), cleaned.rfind("}")
        if start < 0 or end <= start:
            raise
        parsed = json.loads(cleaned[start:end + 1])
    if not isinstance(parsed, dict):
        raise ValueError("AI response must be a JSON object")
    return parsed


# === Data Models ===
class ChatMessage(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    user_id: str = Field(min_length=1, max_length=50)
    conversation_id: Optional[int] = None


class ChatResponse(BaseModel):
    reply: str
    corrections: List[Dict[str, str]] = Field(default_factory=list)
    tips: List[str] = Field(default_factory=list)
    conversation_id: Optional[int] = None
    message_id: Optional[int] = None
    analysis_completed: bool = False
    analysis_message: Optional[str] = None

# === API Endpoints ===

@router.post("/chat", response_model=ChatResponse)
def chat(
    request: ChatMessage,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Main chat endpoint with error detection and database saving."""
    
    # 1. Get or create user
    enforce_owner(request.user_id, current_user)
    user = current_user
    
    # 2. Load or create a durable conversation and save the learner turn.
    conversation = None
    if request.conversation_id is not None:
        conversation = db.query(Conversation).filter(
            Conversation.id == request.conversation_id,
            Conversation.user_id == user.id,
            Conversation.is_active == 1,
        ).first()
    if conversation is None:
        conversation = db.query(Conversation).filter(
            Conversation.user_id == user.id,
            Conversation.is_active == 1,
        ).order_by(Conversation.updated_at.desc()).first()
    if conversation is None:
        conversation = Conversation(user_id=user.id)
        db.add(conversation)
        db.flush()

    previous_messages = db.query(Message).filter(
        Message.conversation_id == conversation.id,
    ).order_by(Message.created_at.desc()).limit(6).all()
    previous_messages.reverse()
    user_message = Message(conversation_id=conversation.id, role="user", content=request.message)
    db.add(user_message)
    db.flush()
    context_messages = [{"role": item.role, "content": item.content} for item in previous_messages]

    # 3. Detect errors
    errors = detect_errors(request.message)
    
    # 3. Save errors to database and keep only new corrections for this response.
    fresh_errors = []
    for error_data in errors:
        # Check if error already exists for this user
        existing_error = db.query(UserError).filter(
            UserError.user_id == user.id,
            UserError.wrong_text == error_data["wrong_text"],
            UserError.mastered == False
        ).first()
        
        if existing_error:
            # Increment count
            existing_error.count += 1
            existing_error.last_occurrence = datetime.utcnow()
            print(f"🔄 Error repeated: {existing_error.wrong_text} (count: {existing_error.count})")
        else:
            # Create new error
            new_error = UserError(
                user_id=user.id,
                error_type=error_data["error_type"],
                wrong_text=error_data["wrong_text"],
                correct_text=error_data["correct_text"],
                explanation=error_data["explanation"],
                context=request.message
            )
            db.add(new_error)
            fresh_errors.append(error_data)
            print(f"📝 New error saved: {new_error.wrong_text}")
    
    db.commit()
    
    # 4. Get an AI response calibrated to the stored level.
    assessed_level = (user.level or '').strip().lower()
    tutor_level = assessed_level if assessed_level not in {'', 'pending', 'intermediate'} or (user.level_score or 0) > 0 else 'not assessed yet'
    reply = 'تم استلام رسالتك، لكن مزود الذكاء الاصطناعي غير مفعّل حاليًا. أضف مفتاحًا صالحًا في Backend ثم أعد المحاولة.'
    ai_tips: List[str] = []
    structured_corrections: List[Dict[str, str]] = []
    analysis_completed = False
    analysis_message: Optional[str] = 'لم يكتمل تحليل الذكاء الاصطناعي لهذه الرسالة.'

    prompt = f"""
    You are an adaptive English conversation tutor. The learner's assessed level is: {tutor_level}.
    Do not claim a higher level than the evidence supports. If the learner is not assessed yet, use simple, natural English and gather evidence gradually.
    Recent conversation context (oldest to newest): {context_messages}
    Learner message: {request.message}
    New errors found in this message: {fresh_errors}

    Requirements:
    1. Reply naturally at the learner's demonstrated level.
    2. Correct only genuine grammar or vocabulary errors from this message, briefly and contextually.
    3. Do not repeat a correction that is not in the new errors list.
    4. Ask one fresh, relevant follow-up question; do not reuse a fixed prompt.
    5. Do not make pronunciation claims from text alone.
    6. Return only valid JSON with this shape:
       {{"reply":"...","corrections":[{{"wrong":"...","correct":"...","explanation":"..."}}],"tips":["..."]}}
    """

    provider_adapter = create_text_provider()
    provider = provider_adapter.__class__.__name__.replace('TextProvider', '').lower()
    provider_key_available = provider_adapter.available

    if provider_key_available:
        try:
            generated = provider_adapter.generate_text(
                system_prompt='You are an adaptive English tutor. Return valid JSON only.',
                user_prompt=prompt,
                temperature=0.4,
                json_mode=True,
            )
            if generated is None:
                raise RuntimeError(f'{provider} provider is not configured')
            raw_output = generated.value

            parsed = _parse_json_object(raw_output)
            if isinstance(parsed.get("reply"), str) and parsed["reply"].strip():
                reply = parsed["reply"].strip()
                analysis_completed = True
                analysis_message = None
            if isinstance(parsed.get("corrections"), list):
                structured_corrections = [
                    {
                        "wrong": str(item.get("wrong", "")),
                        "correct": str(item.get("correct", "")),
                        "explanation": str(item.get("explanation", "")),
                    }
                    for item in parsed["corrections"]
                    if isinstance(item, dict) and item.get("wrong") and item.get("correct")
                ]
            ai_tips = [str(item) for item in parsed.get("tips", []) if item]
        except (json.JSONDecodeError, TypeError, ValueError) as exc:
            print(f"AI structured output error: {exc}")
            analysis_message = 'لم يكتمل تحليل هذه الرسالة لأن مزود AI أعاد نتيجة غير مفهومة. حاول مرة أخرى.'
            reply = analysis_message
        except Exception as exc:
            # Do not expose provider keys, quota details, or stack traces to app users.
            print(f"AI chat provider error: {exc}")
            message = str(exc).lower()
            if '429' in message or 'quota' in message or 'insufficient_quota' in message:
                analysis_message = 'لم يكتمل تحليل هذه الرسالة لأن حد استخدام مزود AI انتهى. تحقق من الخطة أو استخدم مزودًا آخر.'
            elif 'api key not valid' in message or 'invalid api key' in message or 'permission denied' in message or '401' in message or '403' in message:
                analysis_message = f'مفتاح مزود {provider.upper()} غير صالح أو غير مفعّل. راجع إعدادات Backend ثم أعد تشغيل الخادم.'
            elif '404' in message or 'not found' in message:
                analysis_message = f'نموذج {provider.upper()} المحدد غير متاح لهذا المفتاح. راجع إعداد النموذج في Backend.'
            elif 'timeout' in message or 'timed out' in message:
                analysis_message = 'انتهت مهلة الاتصال بمزود AI. تحقق من الإنترنت ثم حاول مرة أخرى.'
            else:
                analysis_message = 'لم يكتمل تحليل هذه الرسالة بسبب تعذر الوصول إلى مزود AI. تحقق من إعدادات Backend ثم أعد المحاولة.'
            reply = analysis_message
    else:
        analysis_message = f'لم يكتمل تحليل هذه الرسالة لأن مزود {provider.upper()} غير مهيأ. تحقق من مفتاحه في Backend/.env ثم أعد تشغيل الخادم.'
        reply = analysis_message
    
    # 5. Prepare corrections
    corrections = structured_corrections or [
        {
            "wrong": e["wrong_text"],
            "correct": e["correct_text"],
            "explanation": e["explanation"]
        }
        for e in fresh_errors
    ]
    
    # 6. Tips: keep deterministic feedback and append structured provider tips.
    tips = list(ai_tips)
    if not tips:
        if fresh_errors:
            tips.append(f"📝 لاحظت {len(fresh_errors)} ملاحظة جديدة في رسالتك.")
        elif errors:
            tips.append("تم تسجيل هذه الملاحظة سابقًا؛ ركّز على استخدامها في سياق جديد.")
        else:
            tips.append("🌟 لم تظهر أخطاء واضحة في هذه الرسالة.")

    assistant_message = Message(conversation_id=conversation.id, role="assistant", content=reply)
    db.add(assistant_message)
    conversation.updated_at = datetime.utcnow()
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(assistant_message)

    return ChatResponse(
        reply=reply,
        corrections=corrections,
        tips=tips,
        conversation_id=conversation.id,
        message_id=assistant_message.id,
        analysis_completed=analysis_completed,
        analysis_message=analysis_message,
    )


@router.get("/test")
async def test():
    """Test endpoint."""
    return {"message": "API is working!"}


@router.get("/errors/{user_id}")
async def get_user_errors(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all errors for a specific user."""
    
    # Find user
    enforce_owner(user_id, current_user)
    user = current_user
    if not user:
        return {"error": "User not found", "errors": []}
    
    # Get all unmastered errors
    errors = db.query(UserError).filter(
        UserError.user_id == user.id,
        UserError.mastered == False
    ).order_by(UserError.count.desc()).all()
    
    # Get statistics
    total_errors = db.query(UserError).filter(UserError.user_id == user.id).count()
    mastered_errors = db.query(UserError).filter(
        UserError.user_id == user.id,
        UserError.mastered == True
    ).count()
    
    return {
        "user_id": user_id,
        "user_name": user.name,
        "level": user.level,
        "statistics": {
            "total": total_errors,
            "mastered": mastered_errors,
            "unmastered": len(errors),
            "mastery_rate": round((mastered_errors / total_errors * 100) if total_errors > 0 else 0, 1)
        },
        "errors": [
            {
                "id": e.id,
                "wrong": e.wrong_text,
                "correct": e.correct_text,
                "explanation": e.explanation,
                "error_type": e.error_type,
                "count": e.count,
                "last_occurrence": e.last_occurrence.isoformat()
            }
            for e in errors
        ]
    }


@router.post("/errors/{error_id}/master")
async def mark_error_mastered(
    error_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark an error as mastered."""
    
    error = db.query(UserError).filter(UserError.id == error_id, UserError.user_id == current_user.id).first()
    if not error:
        raise HTTPException(status_code=404, detail="Error not found")
    
    error.mastered = True
    db.commit()
    
    return {
        "message": f"✅ Error '{error.wrong_text}' marked as mastered!",
        "error_id": error_id
    }


@router.get("/stats/{user_id}")
async def get_user_stats(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get user statistics and progress."""
    
    enforce_owner(user_id, current_user)
    user = current_user
    if not user:
        return {"error": "User not found"}
    
    # Get error statistics
    total_errors = db.query(UserError).filter(UserError.user_id == user.id).count()
    mastered_errors = db.query(UserError).filter(
        UserError.user_id == user.id,
        UserError.mastered == True
    ).count()
    
    # Error type distribution
    grammar_errors = db.query(UserError).filter(
        UserError.user_id == user.id,
        UserError.error_type == "grammar"
    ).count()
    vocabulary_errors = db.query(UserError).filter(
        UserError.user_id == user.id,
        UserError.error_type == "vocabulary"
    ).count()
    
    return {
        "user_id": user_id,
        "user_name": user.name,
        "level": user.level,
        "level_score": user.level_score,
        "total_sessions": user.total_sessions,
        "streak_days": user.streak_days,
        "statistics": {
            "total_errors": total_errors,
            "mastered_errors": mastered_errors,
            "mastery_rate": round((mastered_errors / total_errors * 100) if total_errors > 0 else 0, 1),
            "error_types": {
                "grammar": grammar_errors,
                "vocabulary": vocabulary_errors
            }
        }
    }


@router.delete("/errors/{error_id}")
async def delete_error(
    error_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a specific error (for testing)."""
    
    error = db.query(UserError).filter(UserError.id == error_id, UserError.user_id == current_user.id).first()
    if not error:
        raise HTTPException(status_code=404, detail="Error not found")
    
    db.delete(error)
    db.commit()
    
    return {"message": f"✅ Error {error_id} deleted!"}
