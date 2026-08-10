"""
User model for storing account information.
"""

from sqlalchemy import Column, Integer, String, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from ..core.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(50), nullable=False)
    email = Column(String(100), unique=True, nullable=True)
    
    # Level and progress
    level = Column(String(20), default="intermediate")
    level_score = Column(Integer, default=0)
    
    # Statistics
    total_sessions = Column(Integer, default=0)
    total_errors = Column(Integer, default=0)
    mastered_errors = Column(Integer, default=0)
    streak_days = Column(Integer, default=0)
    
    # Status
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_active = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    errors = relationship("UserError", back_populates="user")
