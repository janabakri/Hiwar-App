"""Evidence-based daily plan and progress endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...ai.agents.tutor_orchestrator import TutorOrchestrator
from ...ai.contracts.memory import LearningPlan, ProgressSnapshot
from ...core.auth import get_current_user
from ...core.database import get_db
from ...models.user import User


router = APIRouter()


@router.get("/learning-plan/today", response_model=LearningPlan)
def get_today_plan(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> LearningPlan:
    return TutorOrchestrator(db).today_plan(user)


@router.get("/progress", response_model=ProgressSnapshot)
def get_tutor_progress(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProgressSnapshot:
    return TutorOrchestrator(db).progress(user)
