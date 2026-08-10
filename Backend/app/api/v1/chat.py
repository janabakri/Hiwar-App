"""
Chat API endpoints.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Dict

from ...core.database import get_db
from ...core.config import settings  
from ...services.error_tracker import detect_errors

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
    """Main chat endpoint with error detection."""
    
    # 1. Detect errors
    errors = detect_errors(request.message)
    
    # 2. Save user and errors (coming soon)
    
    # 3. Get AI response
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
                model=settings.OPENAI_MODEL,
                messages=[{"role": "user", "content": prompt}]
            )
            
            ai_reply = response.choices[0].message.content
            if ai_reply:
                reply = ai_reply
                
        except Exception as exc:
            reply = f"OpenAI request failed. Details: {exc}"
    
    # 4. Prepare corrections
    corrections = [
        {
            "wrong": e["wrong_text"],
            "correct": e["correct_text"],
            "explanation": e["explanation"]
        }
        for e in errors
    ]
    
    # 5. Tips
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