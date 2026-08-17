"""
Chat API endpoints with database integration.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Dict, Optional
from datetime import datetime

from ...core.database import get_db
from ...core.config import settings
from ...services.error_tracker import detect_errors
from ...models.user import User
from ...models.error import UserError
from openai import OpenAI

router = APIRouter()

# === Data Models ===
class ChatMessage(BaseModel):
    message: str
    user_id: str

class ChatResponse(BaseModel):
    reply: str
    corrections: List[Dict] = []
    tips: List[str] = []

# === API Endpoints ===

@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatMessage,
    db: Session = Depends(get_db)
):
    """Main chat endpoint with error detection and database saving."""
    
    # 1. Get or create user
    user = db.query(User).filter(User.user_id == request.user_id).first()
    if not user:
        user = User(
            user_id=request.user_id,
            name=f"User_{request.user_id[:5]}",
            level="intermediate"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        print(f"✅ New user created: {user.user_id}")
    
    # 2. Detect errors
    errors = detect_errors(request.message)
    
    # 3. Save errors to database
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
            print(f"📝 New error saved: {new_error.wrong_text}")
    
    db.commit()
    
    # 4. Get AI response
    reply = "Your message was received. I can help you improve it with gentle corrections."

    if settings.OPENAI_API_KEY:
        try:
            client = OpenAI(
                api_key=settings.OPENAI_API_KEY,
                base_url=settings.OPENAI_BASE_URL
            )
            
            prompt = f"""
            You are an English teacher. Level: intermediate.
            User message: {request.message}
            
            Detected errors: {errors}
            
            Requirements:
            1. Reply naturally in English
            2. Correct errors gently
            3. If error is repeated, point it out
            """

            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7,
                max_tokens=300
            )
            
            ai_reply = response.choices[0].message.content
            if ai_reply:
                reply = ai_reply
                
        except Exception as exc:
            # Do not expose provider keys, quota details, or stack traces to app users.
            print(f"AI chat provider error: {exc}")
            message = str(exc).lower()
            if '429' in message or 'quota' in message or 'insufficient_quota' in message:
                reply = 'خدمة التحليل الذكي مشغولة حاليًا. تم حفظ رسالتك، حاول مرة أخرى بعد قليل.'
            else:
                reply = 'تعذر الحصول على رد الذكاء الاصطناعي الآن، لكن يمكنك متابعة التدريب والمحاولة مرة أخرى.'
    
    # 5. Prepare corrections
    corrections = [
        {
            "wrong": e["wrong_text"],
            "correct": e["correct_text"],
            "explanation": e["explanation"]
        }
        for e in errors
    ]
    
    # 6. Tips
    tips = []
    if errors:
        tips.append(f"📝 Found {len(errors)} error(s). Check corrections above.")
    else:
        tips.append("🌟 Great! No errors detected.")
    
    return ChatResponse(
        reply=reply,
        corrections=corrections,
        tips=tips
    )


@router.get("/test")
async def test():
    """Test endpoint."""
    return {"message": "API is working!"}


@router.get("/errors/{user_id}")
async def get_user_errors(
    user_id: str,
    db: Session = Depends(get_db)
):
    """Get all errors for a specific user."""
    
    # Find user
    user = db.query(User).filter(User.user_id == user_id).first()
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
    db: Session = Depends(get_db)
):
    """Mark an error as mastered."""
    
    error = db.query(UserError).filter(UserError.id == error_id).first()
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
    db: Session = Depends(get_db)
):
    """Get user statistics and progress."""
    
    user = db.query(User).filter(User.user_id == user_id).first()
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
    db: Session = Depends(get_db)
):
    """Delete a specific error (for testing)."""
    
    error = db.query(UserError).filter(UserError.id == error_id).first()
    if not error:
        raise HTTPException(status_code=404, detail="Error not found")
    
    db.delete(error)
    db.commit()
    
    return {"message": f"✅ Error {error_id} deleted!"}