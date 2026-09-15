"""
User model for storing account information.
"""

from sqlalchemy import Column, Integer, String, Boolean, Text
from sqlalchemy.orm import relationship
from ..core.aware_datetime import UTCDateTime, utc_now
from ..core.database import Base
from .journal import JournalEntry  # noqa: F401  # register relationship target

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(50), nullable=False)
    email = Column(String(100), unique=True, nullable=True)
    auth_provider = Column(String(30), default="manual", nullable=False)
    auth_subject = Column(String(255), nullable=True, index=True)

    # Profile onboarding
    age = Column(Integer, nullable=True)
    education_level = Column(String(80), nullable=True)
    certificates = Column(Text, nullable=True)
    learning_reason = Column(Text, nullable=True)
    daily_minutes = Column(Integer, nullable=True)
    focus_skills = Column(Text, nullable=True)
    profile_complete = Column(Boolean, default=False, nullable=False)
    password_hash = Column(String(255), nullable=True)
    verification_code = Column(String(64), nullable=True)
    verification_expires_at = Column(UTCDateTime, nullable=True)
    email_verified = Column(Boolean, default=False, nullable=False)

    # Level and progress
    level = Column(String(20), default="pending")
    level_score = Column(Integer, default=0)
    # JSON string of the last level test's per-skill breakdown, e.g.
    # {"grammar": 80, "vocabulary": 60, "comprehension": 100, "speaking": 65}
    # (0-100 each). Nullable — older accounts and manual sign-ins won't have it.
    skill_scores = Column(Text, nullable=True)

    # Statistics
    total_sessions = Column(Integer, default=0)
    total_errors = Column(Integer, default=0)
    mastered_errors = Column(Integer, default=0)
    streak_days = Column(Integer, default=0)

    # Status
    is_active = Column(Boolean, default=True)
    created_at = Column(UTCDateTime, default=utc_now)
    last_active = Column(UTCDateTime, default=utc_now, onupdate=utc_now)

    # Relationships
    errors = relationship("UserError", back_populates="user")
    conversations = relationship("Conversation", back_populates="user", cascade="all, delete-orphan")
    journal_entries = relationship("JournalEntry", back_populates="user", cascade="all, delete-orphan")
