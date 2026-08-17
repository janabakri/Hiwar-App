"""Authentication handoff and profile onboarding endpoints.

The current app uses a trusted client user_id; production Google token verification
should be added before exposing this API publicly.
"""
from datetime import datetime, timedelta
from jose import jwt
from typing import Optional
import base64
import hashlib
import hmac
import secrets
import smtplib
from email.message import EmailMessage

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.database import get_db
from ...models.user import User
from ...core.config import settings

router = APIRouter()


class SignInRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=80)
    email: Optional[str] = Field(default=None, max_length=150)
    auth_provider: str = Field(default="manual", max_length=30)
    auth_subject: Optional[str] = Field(default=None, max_length=255)


class SignUpRequest(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    email: str = Field(min_length=5, max_length=150)
    password: str = Field(min_length=8, max_length=128)


class PasswordSignInRequest(BaseModel):
    email: str = Field(min_length=5, max_length=150)
    password: str = Field(min_length=8, max_length=128)


class VerifyEmailRequest(BaseModel):
    email: str = Field(min_length=5, max_length=150)
    code: str = Field(min_length=6, max_length=6)


class ProfileUpdateRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=80)
    age: Optional[int] = Field(default=None, ge=5, le=120)
    education_level: Optional[str] = Field(default=None, max_length=80)
    certificates: Optional[str] = Field(default=None, max_length=1000)
    learning_reason: Optional[str] = Field(default=None, max_length=1200)
    daily_minutes: Optional[int] = Field(default=None, ge=5, le=240)
    focus_skills: Optional[str] = Field(default=None, max_length=500)


def _hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 120_000)
    return base64.urlsafe_b64encode(salt + digest).decode()


def _verify_password(password: str, encoded: str) -> bool:
    try:
        raw = base64.urlsafe_b64decode(encoded.encode())
        salt, expected = raw[:16], raw[16:]
        actual = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 120_000)
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def _issue_token(user: User) -> str:
    now = datetime.utcnow()
    payload = {"sub": user.user_id, "email": user.email, "iat": now, "exp": now + timedelta(hours=24)}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")


def _send_verification_email(email: str, code: str) -> bool:
    if not settings.SMTP_HOST:
        return False
    message = EmailMessage()
    message['Subject'] = 'رمز التحقق من حوار App'
    message['From'] = settings.SMTP_FROM or settings.SMTP_USERNAME
    message['To'] = email
    message.set_content(f'رمز التحقق الخاص بك في حوار App هو: {code}\n\nينتهي الرمز خلال 10 دقائق.')
    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as smtp:
        smtp.starttls()
        if settings.SMTP_USERNAME:
            smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
        smtp.send_message(message)
    return True


def _serialize(user: User):
    return {
        "user_id": user.user_id,
        "name": user.name,
        "email": user.email,
        "age": user.age,
        "education_level": user.education_level,
        "certificates": user.certificates,
        "learning_reason": user.learning_reason,
        "daily_minutes": user.daily_minutes,
        "focus_skills": user.focus_skills,
        "level": user.level,
        "level_score": user.level_score,
        "total_sessions": user.total_sessions,
        "streak_days": user.streak_days,
        "profile_complete": bool(user.profile_complete),
    }


@router.post("/auth/sign-up")
def sign_up(request: SignUpRequest, db: Session = Depends(get_db)):
    email = request.email.strip().lower()
    user = db.query(User).filter(User.email == email).first()
    if user and user.email_verified:
        raise HTTPException(status_code=409, detail="هذا البريد مسجل مسبقًا")
    if not user:
        stable_id = f"email-{hashlib.sha256(email.encode()).hexdigest()[:40]}"
        user = User(user_id=stable_id, name=request.name.strip(), email=email)
        db.add(user)
    code = f"{secrets.randbelow(1_000_000):06d}"
    user.name = request.name.strip()
    user.email = email
    user.password_hash = _hash_password(request.password)
    user.verification_code = code
    user.verification_expires_at = datetime.utcnow() + timedelta(minutes=10)
    user.email_verified = False
    user.auth_provider = "email"
    db.commit()
    try:
        sent = _send_verification_email(email, code)
    except (OSError, smtplib.SMTPException):
        sent = False
    if not sent:
        return {"message": "تم إنشاء الحساب، لكن لم يتم إرسال رسالة البريد. يجب إعداد SMTP في Backend.", "email": email, "sent": False}
    return {"message": "تم إنشاء الحساب. أرسلنا رمز التحقق إلى بريدك الإلكتروني.", "email": email, "sent": True}


@router.post("/auth/verify-email")
def verify_email(request: VerifyEmailRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == request.email.strip().lower()).first()
    if not user or user.verification_code != request.code or not user.verification_expires_at or user.verification_expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="رمز التحقق غير صحيح أو منتهي")
    user.email_verified = True
    user.verification_code = None
    user.verification_expires_at = None
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(user)
    result = _serialize(user)
    result["access_token"] = _issue_token(user)
    result["token_type"] = "bearer"
    return result


@router.post("/auth/password-sign-in")
def password_sign_in(request: PasswordSignInRequest, db: Session = Depends(get_db)):
    email = request.email.strip().lower()
    user = db.query(User).filter(User.email == email).first()
    if not user or not user.password_hash or not _verify_password(request.password, user.password_hash):
        raise HTTPException(status_code=401, detail="البريد أو كلمة المرور غير صحيحة")
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="تحققي من بريدك الإلكتروني أولًا")
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(user)
    result = _serialize(user)
    result["access_token"] = _issue_token(user)
    result["token_type"] = "bearer"
    return result


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
    result = _serialize(user)
    result["access_token"] = _issue_token(user)
    result["token_type"] = "bearer"
    return result


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
    user.daily_minutes = request.daily_minutes
    user.focus_skills = request.focus_skills
    user.profile_complete = True
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(user)
    return _serialize(user)
