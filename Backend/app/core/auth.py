"""Authentication dependency used by the new tutor endpoints.

Legacy endpoints still keep their current contract to avoid breaking the
programmer's ongoing work. New learning-memory endpoints require the JWT that
the existing sign-in flow already issues, so one user cannot request another
user's tutor history by changing a body field.
"""

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from .config import settings
from .database import get_db
from ..models.user import User


bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc

    subject = payload.get("sub")
    if not isinstance(subject, str) or not subject:
        raise HTTPException(status_code=401, detail="Invalid token subject")
    user = db.query(User).filter(User.user_id == subject, User.is_active == True).first()  # noqa: E712
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user
