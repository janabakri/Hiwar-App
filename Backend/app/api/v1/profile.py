"""Authentication handoff and profile onboarding endpoints.

The current app uses a trusted client user_id; production Google token verification
should be added before exposing this API publicly.
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.database import get_db
from ...models.user import User

router = APIRouter()


class SignInRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=80)
    email: Optional[str] = Field(default=None, max_length=150)
    auth_provider: str = Field(default="manual", max_length=30)
    auth_subject: Optional[str] = Field(default=None, max_length=255)


class ProfileUpdateRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=80)
    age: Optional[int] = Field(default=None, ge=5, le=120)
    education_level: Optional[str] = Field(default=None, max_length=80)
    certificates: Optional[str] = Field(default=None, max_length=1000)
    learning_reason: Optional[str] = Field(default=None, max_length=1200)


def _serialize(user: User):
    return {
        "user_id": user.user_id,
        "name": user.name,
        "email": user.email,
        "age": user.age,
        "education_level": user.education_level,
        "certificates": user.certificates,
        "learning_reason": user.learning_reason,
        "level": user.level,
        "level_score": user.level_score,
        "total_sessions": user.total_sessions,
        "streak_days": user.streak_days,
        "profile_complete": bool(user.profile_complete),
    }


@router.post("/auth/sign-in")
def sign_in(request: SignInRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.user_id == request.user_id).first()
    if not user:
        user = User(user_id=request.user_id, name=request.name)
        db.add(user)
    user.name = request.name
    user.email = request.email
    user.auth_provider = request.auth_provider
    user.auth_subject = request.auth_subject
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(user)
    return _serialize(user)


@router.get("/profile/{user_id}")
def get_profile(user_id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _serialize(user)


@router.put("/profile")
def update_profile(request: ProfileUpdateRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.user_id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.name = request.name
    user.age = request.age
    user.education_level = request.education_level
    user.certificates = request.certificates
    user.learning_reason = request.learning_reason
    user.profile_complete = True
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(user)
    return _serialize(user)
