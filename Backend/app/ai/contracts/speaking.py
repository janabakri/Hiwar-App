from typing import Literal

from pydantic import Field

from .base import StrictContract
from .memory import LearningCandidate


class FeedbackItem(StrictContract):
    type: Literal["grammar", "vocabulary", "fluency", "naturalness", "meaning", "pronunciation"]
    code: str = Field(min_length=2, max_length=140)
    wrong: str = Field(min_length=1, max_length=500)
    corrected: str = Field(min_length=1, max_length=500)
    explanation_ar: str = Field(min_length=1, max_length=1200)
    confidence: float = Field(ge=0, le=1)


class SpeakingScores(StrictContract):
    grammar: int | None = Field(ge=0, le=100)
    vocabulary: int | None = Field(ge=0, le=100)
    fluency: int | None = Field(ge=0, le=100)
    pronunciation: int | None = Field(ge=0, le=100)
    naturalness: int | None = Field(ge=0, le=100)
    interactive_communication: int | None = Field(ge=0, le=100)


class SpeakingSessionPlan(StrictContract):
    cefr_level: str = Field(min_length=2, max_length=10)
    mode: Literal["conversation", "coach", "scenario", "assessment"]
    topic: str = Field(min_length=1, max_length=120)
    goal: str = Field(min_length=1, max_length=250)
    opening_prompt: str = Field(min_length=1, max_length=600)
    target_skill_codes: list[str] = Field(max_length=2)
    correction_limit: int = Field(ge=1, le=2)


class SpeakingTurnAnalysis(StrictContract):
    meaning_understood: bool
    transcript: str = Field(min_length=1, max_length=5000)
    assistant_reply: str = Field(min_length=1, max_length=900)
    corrected_utterance: str = Field(min_length=1, max_length=5000)
    natural_alternative: str = Field(min_length=1, max_length=5000)
    priority_feedback: list[FeedbackItem] = Field(max_length=2)
    scores: SpeakingScores
    retry_required: bool
    retry_phrase: str = Field(max_length=1000)
    memory_candidates: list[LearningCandidate] = Field(max_length=2)
    next_action: Literal["ask_follow_up", "request_retry", "simplify", "finish"]


class RetryAnalysis(StrictContract):
    successful: bool
    similarity_score: int = Field(ge=0, le=100)
    improvement: int = Field(ge=-100, le=100)
    feedback_ar: str
    next_action: Literal["continue", "retry_again", "finish"]


class SpeakingSessionSummary(StrictContract):
    achievements: list[str] = Field(max_length=3)
    review_focus: str = Field(max_length=500)
    evidence_count: int = Field(ge=0)
    average_scores: SpeakingScores
    next_activity: Literal["speaking", "reading", "review"]
    message_ar: str = Field(max_length=1200)
