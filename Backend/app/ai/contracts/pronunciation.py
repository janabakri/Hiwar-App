"""Validated public contract for evidence-based pronunciation feedback."""

from typing import Literal

from pydantic import Field

from .base import StrictContract


class PronunciationPhonemeScore(StrictContract):
    phoneme: str = Field(min_length=1, max_length=40)
    accuracy_score: float | None = Field(default=None, ge=0, le=100)


class PronunciationWordScore(StrictContract):
    word: str = Field(min_length=1, max_length=100)
    accuracy_score: float | None = Field(default=None, ge=0, le=100)
    error_type: str = Field(default="None", max_length=80)
    offset_ms: int | None = Field(default=None, ge=0)
    duration_ms: int | None = Field(default=None, ge=0)
    phonemes: list[PronunciationPhonemeScore] = Field(default_factory=list, max_length=40)


class PronunciationAssessmentResult(StrictContract):
    provider: Literal["azure_speech"] = "azure_speech"
    model: Literal["pronunciation-assessment"] = "pronunciation-assessment"
    locale: str = Field(min_length=4, max_length=20)
    reference_text: str = Field(min_length=1, max_length=1200)
    recognized_text: str = Field(min_length=1, max_length=1200)
    pronunciation_score: float | None = Field(default=None, ge=0, le=100)
    accuracy_score: float = Field(ge=0, le=100)
    fluency_score: float | None = Field(default=None, ge=0, le=100)
    completeness_score: float | None = Field(default=None, ge=0, le=100)
    prosody_score: float | None = Field(default=None, ge=0, le=100)
    reference_match_score: int = Field(ge=0, le=100)
    reliable: bool
    warning_ar: str | None = Field(default=None, max_length=500)
    words: list[PronunciationWordScore] = Field(default_factory=list, max_length=160)
    audio_retained: Literal[False] = False
