"""
LevelHistory model — permanent record of every level-assessment attempt.

The User row only keeps the LATEST level/score (fast lookup). This table
keeps the FULL history so the app can prove real progress over time
("improved from 60% to 75%") with the user's own numbers, not marketing.
"""

from sqlalchemy import Column, Integer, String, DateTime, Index
from datetime import datetime

from ..core.database import Base


class LevelHistory(Base):
    __tablename__ = "level_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), index=True, nullable=False)
    level = Column(String(20), nullable=False)
    score = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        Index("ix_level_history_user_created", "user_id", "created_at"),
    )