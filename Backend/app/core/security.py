"""JWT authentication and ownership enforcement shared by protected endpoints."""

from datetime import datetime, timedelta

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from .config import settings
from .database import get_db
from ..models.user import User

ALGORITHM = "HS256"
bearer = HTTPBearer(auto_error=False)


def create_access_token(user: User) -> str:
    if not settings.SECRET_KEY:
        raise RuntimeError("SECRET_KEY is required to issue access tokens")
    now = datetime.utcnow()
    return jwt.encode(
        {
            "sub": user.user_id,
            "iat": now,
            "exp": now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        },
        settings.SECRET_KEY,
        algorithm=ALGORITHM,
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or not settings.SECRET_KEY:
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        payload = jwt.decode(credentials.credentials, settings.SECRET_KEY, algorithms=[ALGORITHM])
        subject = payload.get("sub")
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
    user = db.query(User).filter(User.user_id == subject, User.is_active.is_(True)).first()
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid account")
    return user


def enforce_owner(requested_user_id: str, current_user: User) -> None:
    if requested_user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="You cannot access another user's data")
