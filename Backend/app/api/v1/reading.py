"""Authenticated API for adaptive reading lessons."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import Field, field_validator, model_validator
from sqlalchemy.orm import Session

from ...ai.agents.tutor_orchestrator import TutorOrchestrator
from ...ai.contracts.base import StrictContract
from ...ai.contracts.reading import PublicReadingLesson, ReadingAnswerAnalysis, ReadingSessionSummary
from ...core.auth import get_current_user
from ...core.database import get_db
from ...models.user import User


router = APIRouter()


class StartReadingRequest(StrictContract):
    level: str | None = Field(default=None, max_length=10)
    topic: str | None = Field(default=None, max_length=120)
    source_text: str | None = Field(default=None, max_length=5000)

    @field_validator("level", "topic")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None

    @model_validator(mode="after")
    def validate_source_text(self):
        if self.source_text is not None and len(self.source_text.strip()) < 40:
            raise ValueError("source_text must contain at least 40 characters")
        return self


class StartReadingResponse(StrictContract):
    session_id: str
    material_id: str
    lesson: PublicReadingLesson


class ReadingAnswerRequest(StrictContract):
    question_id: str = Field(min_length=1, max_length=80)
    answer: str = Field(min_length=1, max_length=2000)

    @field_validator("question_id", "answer")
    @classmethod
    def reject_blank_text(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("value must not be blank")
        return stripped


class ReadingAnswerResponse(StrictContract):
    attempt_id: str
    analysis: ReadingAnswerAnalysis


@router.post("/reading/sessions", response_model=StartReadingResponse)
def start_reading_session(
    request: StartReadingRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> StartReadingResponse:
    session, material, lesson = TutorOrchestrator(db).start_reading(
        user=user,
        level=request.level,
        topic=request.topic,
        source_text=request.source_text.strip() if request.source_text else None,
    )
    return StartReadingResponse(
        session_id=session.public_id,
        material_id=material.public_id,
        lesson=PublicReadingLesson.from_lesson(lesson),
    )


@router.post("/reading/sessions/{session_id}/answers", response_model=ReadingAnswerResponse)
def submit_reading_answer(
    session_id: str,
    request: ReadingAnswerRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReadingAnswerResponse:
    try:
        attempt, analysis = TutorOrchestrator(db).reading_answer(
            user=user,
            session_public_id=session_id,
            question_id=request.question_id,
            answer=request.answer.strip(),
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return ReadingAnswerResponse(attempt_id=attempt.public_id, analysis=analysis)


@router.post("/reading/sessions/{session_id}/finish", response_model=ReadingSessionSummary)
def finish_reading_session(
    session_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReadingSessionSummary:
    try:
        return TutorOrchestrator(db).finish_reading(user=user, session_public_id=session_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
