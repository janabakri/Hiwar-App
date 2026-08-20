from datetime import datetime
from typing import Literal

from pydantic import Field

from .base import StrictContract


class LearningCandidate(StrictContract):
    skill_code: str = Field(min_length=2, max_length=140)
    skill_type: Literal["grammar", "vocabulary", "fluency", "naturalness", "comprehension", "communication", "pronunciation"]
    label: str = Field(min_length=1, max_length=240)
    explanation_ar: str = Field(min_length=1, max_length=1200)
    confidence: float = Field(ge=0, le=1)
    mastery_delta: int = Field(ge=-30, le=30)


class LearningPlan(StrictContract):
    recommended_skill: Literal["speaking", "reading"]
    goal: str = Field(min_length=1, max_length=500)
    reason_ar: str = Field(min_length=1, max_length=1200)
    due_review_count: int = Field(ge=0)
    suggested_minutes: int = Field(ge=5, le=60)


class ProgressMetric(StrictContract):
    skill: str = Field(min_length=1, max_length=40)
    mastery_score: int | None = Field(ge=0, le=100)
    confidence: float = Field(ge=0, le=1)
    evidence_count: int = Field(ge=0)
    trend: Literal["insufficient_evidence", "starting", "improving", "stable", "needs_review"]


class ProgressSnapshot(StrictContract):
    cefr_level: str = Field(min_length=2, max_length=10)
    cefr_confidence: float = Field(ge=0, le=1)
    speaking: ProgressMetric
    reading: ProgressMetric
    due_reviews: int = Field(ge=0)
    total_sessions: int = Field(ge=0)
    generated_at: datetime
