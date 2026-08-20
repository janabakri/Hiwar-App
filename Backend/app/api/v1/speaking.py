"""Authenticated API for adaptive speaking sessions."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import Field, field_validator
from sqlalchemy.orm import Session

from ...ai.agents.tutor_orchestrator import TutorOrchestrator
from ...ai.contracts.base import StrictContract
from ...ai.contracts.speaking import RetryAnalysis, SpeakingSessionPlan, SpeakingSessionSummary, SpeakingTurnAnalysis
from ...core.auth import get_current_user
from ...core.database import get_db
from ...models.user import User


router = APIRouter()


class StartSpeakingRequest(StrictContract):
    mode: str = Field(default="conversation", max_length=30)
    topic: str | None = Field(default=None, max_length=120)
    goal: str | None = Field(default=None, max_length=250)

    @field_validator("topic", "goal")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


class StartSpeakingResponse(StrictContract):
    session_id: str
    plan: SpeakingSessionPlan


class SpeakingTurnRequest(StrictContract):
    transcript: str = Field(min_length=1, max_length=5000)

    @field_validator("transcript")
    @classmethod
    def reject_blank_transcript(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("transcript must not be blank")
        return stripped


class SpeakingTurnResponse(StrictContract):
    turn_id: str
    analysis: SpeakingTurnAnalysis


class SpeakingRetryRequest(StrictContract):
    transcript: str = Field(min_length=1, max_length=2000)

    @field_validator("transcript")
    @classmethod
    def reject_blank_transcript(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("transcript must not be blank")
        return stripped


class SpeakingRetryResponse(StrictContract):
    attempt_id: str
    analysis: RetryAnalysis


@router.post("/speaking/sessions", response_model=StartSpeakingResponse)
def start_speaking_session(
    request: StartSpeakingRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> StartSpeakingResponse:
    session, plan = TutorOrchestrator(db).start_speaking(
        user=user,
        mode=request.mode,
        topic=request.topic,
        goal=request.goal,
    )
    return StartSpeakingResponse(session_id=session.public_id, plan=plan)


@router.post("/speaking/sessions/{session_id}/turns", response_model=SpeakingTurnResponse)
def submit_speaking_turn(
    session_id: str,
    request: SpeakingTurnRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SpeakingTurnResponse:
    try:
        turn, analysis = TutorOrchestrator(db).speaking_turn(
            user=user,
            session_public_id=session_id,
            transcript=request.transcript.strip(),
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return SpeakingTurnResponse(turn_id=turn.public_id, analysis=analysis)


@router.post("/speaking/turns/{turn_id}/retry", response_model=SpeakingRetryResponse)
def retry_speaking_turn(
    turn_id: str,
    request: SpeakingRetryRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SpeakingRetryResponse:
    try:
        attempt, analysis = TutorOrchestrator(db).speaking_retry(
            user=user,
            turn_public_id=turn_id,
            transcript=request.transcript.strip(),
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return SpeakingRetryResponse(attempt_id=attempt.public_id, analysis=analysis)


@router.post("/speaking/sessions/{session_id}/finish", response_model=SpeakingSessionSummary)
def finish_speaking_session(
    session_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SpeakingSessionSummary:
    try:
        return TutorOrchestrator(db).finish_speaking(user=user, session_public_id=session_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
