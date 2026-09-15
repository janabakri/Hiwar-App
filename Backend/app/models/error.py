"""
Error model for tracking user mistakes.
"""

from sqlalchemy import Column, Integer, String, Text, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from ..core.aware_datetime import UTCDateTime, utc_now
from ..core.database import Base

class UserError(Base):
    __tablename__ = "user_errors"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Error details
    error_type = Column(String(50))  # grammar, vocabulary
    wrong_text = Column(Text, nullable=False)
    correct_text = Column(Text, nullable=False)
    explanation = Column(Text)
    context = Column(Text)

    # Tracking
    count = Column(Integer, default=1)  # How many times repeated
    mastered = Column(Boolean, default=False)
    review_count = Column(Integer, default=0)

    # Timestamps
    first_occurrence = Column(UTCDateTime, default=utc_now)
    last_occurrence = Column(UTCDateTime, default=utc_now, onupdate=utc_now)
    
    # Relationship
    user = relationship("User", back_populates="errors")

