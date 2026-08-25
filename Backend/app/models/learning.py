"""Learning-domain models for the adaptive Hiwar tutor.

The model output is never treated as the source of truth by itself. Raw evidence
is stored as ``LearningEvent`` rows, while durable mastery is kept in
``LearningItem`` only after the memory acceptance rules approve it.
"""

from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from ..core.database import Base


def _public_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex}"


def _utc_now_naive() -> datetime:
    """UTC timestamp compatible with the existing naive DateTime columns."""
    return datetime.now(UTC).replace(tzinfo=None)


class ReadingMaterial(Base):
    __tablename__ = "reading_materials"

    id = Column(Integer, primary_key=True, index=True)
    public_id = Column(String(48), unique=True, nullable=False, index=True, default=lambda: _public_id("read"))
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    source_type = Column(String(30), nullable=False, default="generated")
    title = Column(String(200), nullable=False)
    topic = Column(String(120), nullable=False, default="daily life")
    content = Column(Text, nullable=False)
    cefr_level = Column(String(10), nullable=False, default="A1")
    target_words = Column(JSON, nullable=False, default=list)
    questions = Column(JSON, nullable=False, default=list)
    created_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)

    owner = relationship("User")


class TutorSession(Base):
    __tablename__ = "tutor_sessions"

    id = Column(Integer, primary_key=True, index=True)
    public_id = Column(String(48), unique=True, nullable=False, index=True, default=lambda: _public_id("session"))
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    skill = Column(String(20), nullable=False, index=True)
    mode = Column(String(30), nullable=False, default="conversation")
    goal = Column(String(250), nullable=False)
    topic = Column(String(120), nullable=False)
    cefr_level = Column(String(10), nullable=False, default="A1")
    status = Column(String(20), nullable=False, default="active", index=True)
    reading_material_id = Column(Integer, ForeignKey("reading_materials.id"), nullable=True)
    total_turns = Column(Integer, nullable=False, default=0)
    summary = Column(JSON, nullable=True)
    context_data = Column(JSON, nullable=False, default=dict)
    started_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)
    ended_at = Column(DateTime, nullable=True)

    user = relationship("User")
    reading_material = relationship("ReadingMaterial")
    speaking_turns = relationship("SpeakingTurn", back_populates="session", cascade="all, delete-orphan")
    reading_attempts = relationship("ReadingAttempt", back_populates="session", cascade="all, delete-orphan")

    __table_args__ = (Index("ix_tutor_session_user_skill_status", "user_id", "skill", "status"),)


class SpeakingTurn(Base):
    __tablename__ = "speaking_turns"

    id = Column(Integer, primary_key=True, index=True)
    public_id = Column(String(48), unique=True, nullable=False, index=True, default=lambda: _public_id("turn"))
    session_id = Column(Integer, ForeignKey("tutor_sessions.id"), nullable=False, index=True)
    transcript = Column(Text, nullable=False)
    assistant_reply = Column(Text, nullable=False)
    corrected_utterance = Column(Text, nullable=False)
    natural_alternative = Column(Text, nullable=False)
    priority_feedback = Column(JSON, nullable=False, default=list)
    scores = Column(JSON, nullable=False, default=dict)
    retry_required = Column(Boolean, nullable=False, default=False)
    retry_phrase = Column(Text, nullable=False, default="")
    meaning_understood = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)

    session = relationship("TutorSession", back_populates="speaking_turns")
    attempts = relationship("SpeakingAttempt", back_populates="turn", cascade="all, delete-orphan")


class SpeakingAttempt(Base):
    __tablename__ = "speaking_attempts"

    id = Column(Integer, primary_key=True, index=True)
    public_id = Column(String(48), unique=True, nullable=False, index=True, default=lambda: _public_id("attempt"))
    turn_id = Column(Integer, ForeignKey("speaking_turns.id"), nullable=False, index=True)
    attempt_number = Column(Integer, nullable=False, default=1)
    transcript = Column(Text, nullable=False)
    similarity_score = Column(Integer, nullable=False)
    improvement = Column(Integer, nullable=False, default=0)
    successful = Column(Boolean, nullable=False, default=False)
    feedback_ar = Column(Text, nullable=False)
    created_at = Column(DateTime, nullable=False, default=_utc_now_naive)

    turn = relationship("SpeakingTurn", back_populates="attempts")


class ReadingAttempt(Base):
    __tablename__ = "reading_attempts"

    id = Column(Integer, primary_key=True, index=True)
    public_id = Column(String(48), unique=True, nullable=False, index=True, default=lambda: _public_id("answer"))
    session_id = Column(Integer, ForeignKey("tutor_sessions.id"), nullable=False, index=True)
    question_id = Column(String(80), nullable=False)
    question_type = Column(String(30), nullable=False)
    question = Column(Text, nullable=False)
    user_answer = Column(Text, nullable=False)
    correct_answer = Column(Text, nullable=False)
    score = Column(Integer, nullable=False)
    is_correct = Column(Boolean, nullable=False)
    feedback_ar = Column(Text, nullable=False)
    evidence = Column(JSON, nullable=False, default=dict)
    created_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)

    session = relationship("TutorSession", back_populates="reading_attempts")

    __table_args__ = (UniqueConstraint("session_id", "question_id", name="uq_reading_attempt_session_question"),)


class LearningEvent(Base):
    __tablename__ = "learning_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    session_id = Column(Integer, ForeignKey("tutor_sessions.id"), nullable=True, index=True)
    skill_code = Column(String(140), nullable=False, index=True)
    skill_type = Column(String(40), nullable=False)
    source_skill = Column(String(20), nullable=False, index=True)
    evidence_kind = Column(String(40), nullable=False)
    confidence = Column(Float, nullable=False)
    mastery_delta = Column(Integer, nullable=False, default=0)
    accepted_to_memory = Column(Boolean, nullable=False, default=False)
    evidence = Column(JSON, nullable=False, default=dict)
    created_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)

    user = relationship("User")
    session = relationship("TutorSession")

    __table_args__ = (Index("ix_learning_event_user_skill", "user_id", "skill_code"),)


class LearningItem(Base):
    __tablename__ = "learning_items"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    skill_code = Column(String(140), nullable=False)
    skill_type = Column(String(40), nullable=False)
    source_skill = Column(String(20), nullable=False, index=True)
    label = Column(String(240), nullable=False)
    explanation_ar = Column(Text, nullable=False, default="")
    mastery_score = Column(Integer, nullable=False, default=40)
    confidence = Column(Float, nullable=False, default=0.0)
    evidence_count = Column(Integer, nullable=False, default=1)
    status = Column(String(20), nullable=False, default="new", index=True)
    first_seen_at = Column(DateTime, nullable=False, default=_utc_now_naive)
    last_seen_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)
    last_success_at = Column(DateTime, nullable=True)
    next_review_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)
    details = Column(JSON, nullable=False, default=dict)

    user = relationship("User")

    __table_args__ = (
        UniqueConstraint("user_id", "skill_code", name="uq_learning_item_user_skill"),
        Index("ix_learning_item_due", "user_id", "status", "next_review_at"),
    )


class AIUsageEvent(Base):
    __tablename__ = "ai_usage_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    session_id = Column(Integer, ForeignKey("tutor_sessions.id"), nullable=True, index=True)
    feature = Column(String(60), nullable=False, index=True)
    provider = Column(String(30), nullable=False, default="openai")
    model = Column(String(100), nullable=False)
    input_tokens = Column(Integer, nullable=False, default=0)
    output_tokens = Column(Integer, nullable=False, default=0)
    duration_ms = Column(Integer, nullable=False, default=0)
    success = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)


class AgentTrace(Base):
    __tablename__ = "agent_traces"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("tutor_sessions.id"), nullable=True, index=True)
    step = Column(String(80), nullable=False)
    status = Column(String(20), nullable=False)
    duration_ms = Column(Integer, nullable=False, default=0)
    details = Column(JSON, nullable=False, default=dict)
    created_at = Column(DateTime, nullable=False, default=_utc_now_naive, index=True)
