"""Conversation and message persistence for real learner context."""

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Integer, Text
from sqlalchemy.orm import relationship

from ..core.aware_datetime import UTCDateTime, utc_now
from ..core.database import Base


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)
    updated_at = Column(UTCDateTime, default=utc_now, onupdate=utc_now, nullable=False)
    is_active = Column(Integer, default=1, nullable=False)

    user = relationship("User", back_populates="conversations")
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan")


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    conversation_id = Column(Integer, ForeignKey("conversations.id"), nullable=False, index=True)
    role = Column(Text, nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False, index=True)

    conversation = relationship("Conversation", back_populates="messages")
