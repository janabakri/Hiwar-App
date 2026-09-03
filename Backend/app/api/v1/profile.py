"""Authentication handoff and profile onboarding endpoints.

The current app uses a trusted client user_id; production Google token verification
should be added before exposing this API publicly.
"""
from datetime import datetime, timedelta
from jose import jwt, jwk
import httpx
from typing import Optional
import base64
import hashlib
import hmac
import secrets
import smtplib
from email.message import EmailMessage
from email.utils import formataddr

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.database import get_db
from ...models.user import User
from ...models.error import UserError
from ...core.config import settings
from ...core.security import create_access_token, enforce_owner, get_current_user

try:
    from google.oauth2 import id_token as google_id_token
    from google.auth.transport import requests as google_requests
except ImportError:
    google_id_token = None
    google_requests = None

import re

router = APIRouter()

# Reasonable email format check: rejects placeholder domains like example.com,
# missing '@', spaces, and clearly malformed addresses before we try to send mail.
_EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
_RESERVED_DOMAINS = {"example.com", "example.org", "example.net", "test.com", "localhost"}


def _validate_email(email: str) -> str:
    normalized = email.strip().lower()
    if not _EMAIL_RE.match(normalized) or normalized.split('@')[1] in _RESERVED_DOMAINS:
        raise HTTPException(status_code=422, detail="صيغة البريد الإلكتروني غير صحيحة. تأكدي من كتابته بشكل صحيح مثل: name@gmail.com")
    return normalized


class SignInRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=80)
    email: Optional[str] = Field(default=None, max_length=150)
    auth_provider: str = Field(default="manual", max_length=30)
    auth_subject: Optional[str] = Field(default=None, max_length=255)
    id_token: Optional[str] = Field(default=None, max_length=5000)


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


def _normalize_verification_code(value: str) -> str:
    digit_map = str.maketrans('٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')
    return ''.join(value.translate(digit_map).split())


def _verification_digest(email: str, code: str) -> str:
    if not settings.SECRET_KEY:
        raise RuntimeError("SECRET_KEY is required for email verification")
    return hmac.new(settings.SECRET_KEY.encode(), f"{email}:{code}".encode(), hashlib.sha256).hexdigest()


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


def _verify_apple_token(raw_token: Optional[str]) -> dict:
    if not raw_token or not settings.APPLE_CLIENT_ID:
        raise HTTPException(status_code=401, detail="Apple Sign-In is not configured")
    try:
        header = jwt.get_unverified_header(raw_token)
        keys = httpx.get("https://appleid.apple.com/auth/keys", timeout=8).json().get("keys", [])
        key_data = next((item for item in keys if item.get("kid") == header.get("kid")), None)
        if not key_data:
            raise HTTPException(status_code=401, detail="Invalid Apple token key")
        signing_key = jwk.construct(key_data, header.get("alg", "RS256"))
        claims = jwt.decode(raw_token, signing_key, algorithms=[header.get("alg", "RS256")], audience=settings.APPLE_CLIENT_ID, issuer="https://appleid.apple.com")
        if not claims.get("sub"):
            raise HTTPException(status_code=401, detail="Invalid Apple identity")
        return claims
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid Apple token") from exc


def _verify_google_token(raw_token: Optional[str]) -> dict:
    if not raw_token or google_id_token is None or google_requests is None or not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=401, detail="Google OAuth is not configured")
    try:
        claims = google_id_token.verify_oauth2_token(raw_token, google_requests.Request(), settings.GOOGLE_CLIENT_ID)
        if claims.get('email_verified') is not True:
            raise HTTPException(status_code=403, detail="Google email is not verified")
        return claims
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid Google token") from exc


def _send_verification_email(email: str, code: str) -> bool:
    if not settings.SMTP_HOST:
        return False
    message = EmailMessage()
    message['Subject'] = 'رمز التحقق من حوار App'
    # From must be a valid email address or the SMTP server rejects the message.
    sender_email = settings.SMTP_USERNAME or settings.SMTP_FROM
    if '@' not in (sender_email or ''):
        raise ValueError('SMTP_FROM/SMTP_USERNAME must be a valid email address')
    message['From'] = formataddr((settings.SMTP_FROM_NAME, sender_email))
    message['To'] = email
    message.set_content(f'رمز التحقق الخاص بك في حوار App هو: {code}\n\nينتهي الرمز خلال 10 دقائق. إذا طلبت رمزًا جديدًا، استخدم آخر رمز وصلك فقط.')
    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as smtp:
        smtp.starttls()
        if settings.SMTP_USERNAME:
            smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
        smtp.send_message(message)
    return True


def _serialize(user: User):
    honest_level = user.level
    if (user.level or '').strip().lower() in {'', 'intermediate', 'pending'} and (user.level_score or 0) <= 0:
        honest_level = 'pending'
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
        "level": honest_level,
        "level_score": user.level_score or 0,
        "total_sessions": user.total_sessions,
        "streak_days": user.streak_days,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "profile_complete": bool(user.profile_complete),
    }


@router.post("/auth/sign-up")
def sign_up(request: SignUpRequest, db: Session = Depends(get_db)):
    email = _validate_email(request.email)
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
    user.verification_code = _verification_digest(email, code)
    user.verification_expires_at = datetime.utcnow() + timedelta(minutes=10)
    user.email_verified = False
    user.auth_provider = "email"
    db.commit()
    try:
        sent = _send_verification_email(email, code)
    except (OSError, smtplib.SMTPException):
        sent = False
    if not sent:
        return {"message": "تم إنشاء الحساب، لكن لم يتم إرسال رسالة البريد. يجب إعداد خدمة البريد.", "email": email, "sent": False}
    return {"message": "تم إنشاء الحساب. أرسلنا رمز التحقق إلى بريدك الإلكتروني.", "email": email, "sent": True}


@router.post("/auth/verify-email")
def verify_email(request: VerifyEmailRequest, db: Session = Depends(get_db)):
    email = _validate_email(request.email)
    code = _normalize_verification_code(request.code)
    user = db.query(User).filter(User.email == email).first()
    expected = _verification_digest(email, code)
    if not user or not hmac.compare_digest(user.verification_code or '', expected) or not user.verification_expires_at or user.verification_expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="رمز التحقق غير صحيح أو منتهي")
    user.email_verified = True
    user.verification_code = None
    user.verification_expires_at = None
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(user)
    result = _serialize(user)
    result["access_token"] = create_access_token(user)
    result["token_type"] = "bearer"
    return result


@router.post("/auth/password-sign-in")
def password_sign_in(request: PasswordSignInRequest, db: Session = Depends(get_db)):
    email = _validate_email(request.email)
    user = db.query(User).filter(User.email == email).first()
    if not user or not user.password_hash or not _verify_password(request.password, user.password_hash):
        raise HTTPException(status_code=401, detail="البريد أو كلمة المرور غير صحيحة")
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="تحققي من بريدك الإلكتروني أولًا")
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(user)
    result = _serialize(user)
    result["access_token"] = create_access_token(user)
    result["token_type"] = "bearer"
    return result


@router.post("/auth/sign-in")
def sign_in(request: SignInRequest, db: Session = Depends(get_db)):
    if request.auth_provider == 'google':
        claims = _verify_google_token(request.id_token)
        stable_prefix = 'google'
    elif request.auth_provider == 'apple':
        claims = _verify_apple_token(request.id_token)
        stable_prefix = 'apple'
    else:
        if not settings.ALLOW_MANUAL_AUTH:
            raise HTTPException(status_code=400, detail="Manual sign-in is disabled")
        claims = {}
        stable_prefix = 'manual'
    verified_email = claims.get('email') if claims else request.email
    verified_subject = claims.get('sub') if claims else request.auth_subject
    verified_name = claims.get('name') or request.name
    stable_user_id = f"{stable_prefix}-{verified_subject}" if verified_subject else request.user_id
    user = db.query(User).filter(User.user_id == stable_user_id).first()
    if not user:
        user = User(user_id=stable_user_id, name=verified_name)
        db.add(user)
    user.name = verified_name
    user.email = verified_email
    user.auth_provider = request.auth_provider
    user.auth_subject = verified_subject
    user.email_verified = True
    user.last_active = datetime.utcnow()
    db.commit()
    db.refresh(user)
    result = _serialize(user)
    result["access_token"] = create_access_token(user)
    result["token_type"] = "bearer"
    return result


@router.delete("/account", status_code=204)
def delete_account(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Permanently delete the authenticated account and all owned learning data.

    UserError has no ORM delete cascade in older database schemas, so it is
    removed explicitly. Conversations are deleted through User's cascade,
    which also removes their messages via Conversation.messages.
    """
    try:
        db.query(UserError).filter(UserError.user_id == current_user.id).delete(
            synchronize_session=False
        )
        db.delete(current_user)
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="تعذر حذف الحساب نهائيًا") from exc
    return None


@router.get("/profile/{user_id}")
def get_profile(user_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    enforce_owner(user_id, current_user)
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _serialize(user)


@router.put("/profile")
def update_profile(request: ProfileUpdateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    enforce_owner(request.user_id, current_user)
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
