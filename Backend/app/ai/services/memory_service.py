"""Evidence-gated learner memory and review scheduling."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import desc
from sqlalchemy.orm import Session

from ...core.config import settings
from ...models.learning import LearningEvent, LearningItem, TutorSession
from ...models.user import User
from ..contracts.memory import LearningCandidate, ProgressMetric, ProgressSnapshot
from .scoring_service import ScoringService


class MemoryService:
    def __init__(self, db: Session):
        self.db = db

    def recent_items(self, user: User, *, limit: int = 8, source_skill: str | None = None) -> list[LearningItem]:
        query = self.db.query(LearningItem).filter(LearningItem.user_id == user.id)
        if source_skill:
            query = query.filter(LearningItem.source_skill == source_skill)
        return query.order_by(desc(LearningItem.last_seen_at)).limit(limit).all()

    def due_items(self, user: User, *, limit: int = 10) -> list[LearningItem]:
        now = datetime.now(UTC).replace(tzinfo=None)
        return (
            self.db.query(LearningItem)
            .filter(
                LearningItem.user_id == user.id,
                LearningItem.next_review_at <= now,
                LearningItem.status != "mastered",
            )
            .order_by(LearningItem.next_review_at.asc())
            .limit(limit)
            .all()
        )

    def profile_context(self, user: User, *, source_skill: str | None = None) -> dict:
        items = self.recent_items(user, source_skill=source_skill)
        return {
            "level": ScoringService.normalize_cefr(user.level),
            "learning_reason": user.learning_reason or "daily communication",
            "focus_skills": user.focus_skills or "Speaking, Reading",
            "daily_minutes": user.daily_minutes or 15,
            "recent_learning_items": [
                {
                    "skill_code": item.skill_code,
                    "label": item.label,
                    "mastery_score": item.mastery_score,
                    "confidence": round(item.confidence, 3),
                    "status": item.status,
                }
                for item in items
            ],
        }

    def record_candidates(
        self,
        *,
        user: User,
        session: TutorSession | None,
        candidates: list[LearningCandidate],
        source_skill: str,
        evidence_kind: str,
        evidence: dict,
    ) -> list[LearningItem]:
        accepted_items: list[LearningItem] = []
        now = datetime.now(UTC).replace(tzinfo=None)

        for candidate in candidates:
            prior_events = (
                self.db.query(LearningEvent)
                .filter(
                    LearningEvent.user_id == user.id,
                    LearningEvent.skill_code == candidate.skill_code,
                )
                .count()
            )
            independently_confirmed = evidence_kind in {"rule_confirmed", "retry_failure", "reading_answer"}
            accepted = (
                candidate.confidence >= settings.MEMORY_MIN_CONFIDENCE
                or prior_events + 1 >= settings.MEMORY_REPEAT_THRESHOLD
                or independently_confirmed
            )
            event = LearningEvent(
                user_id=user.id,
                session_id=session.id if session else None,
                skill_code=candidate.skill_code,
                skill_type=candidate.skill_type,
                source_skill=source_skill,
                evidence_kind=evidence_kind,
                confidence=candidate.confidence,
                mastery_delta=candidate.mastery_delta,
                accepted_to_memory=accepted,
                evidence={**evidence, "label": candidate.label},
            )
            self.db.add(event)

            if not accepted:
                continue

            item = (
                self.db.query(LearningItem)
                .filter(
                    LearningItem.user_id == user.id,
                    LearningItem.skill_code == candidate.skill_code,
                )
                .first()
            )
            if item is None:
                initial = 50 + candidate.mastery_delta
                item = LearningItem(
                    user_id=user.id,
                    skill_code=candidate.skill_code,
                    skill_type=candidate.skill_type,
                    source_skill=source_skill,
                    label=candidate.label,
                    explanation_ar=candidate.explanation_ar,
                    mastery_score=ScoringService.clamp(initial),
                    confidence=candidate.confidence,
                    evidence_count=1,
                    first_seen_at=now,
                    last_seen_at=now,
                )
                self.db.add(item)
            else:
                old_count = max(1, item.evidence_count)
                item.confidence = ((item.confidence * old_count) + candidate.confidence) / (old_count + 1)
                item.evidence_count = old_count + 1
                item.mastery_score = ScoringService.clamp(item.mastery_score + candidate.mastery_delta)
                item.last_seen_at = now
                item.label = candidate.label
                item.explanation_ar = candidate.explanation_ar
                if candidate.mastery_delta > 0:
                    item.last_success_at = now

            item.status = self._status_for(item.mastery_score, item.status, candidate.mastery_delta)
            item.next_review_at = self._next_review(now, item.mastery_score)
            accepted_items.append(item)

        return accepted_items

    @staticmethod
    def _status_for(score: int, prior_status: str, delta: int) -> str:
        if prior_status == "mastered" and delta < 0:
            return "relapsed"
        if score >= 85:
            return "mastered"
        if score >= 60:
            return "reviewing"
        if score >= 35:
            return "learning"
        return "new"

    @staticmethod
    def _next_review(now: datetime, score: int) -> datetime:
        if score >= 85:
            days = 30
        elif score >= 70:
            days = 14
        elif score >= 55:
            days = 7
        elif score >= 35:
            days = 3
        else:
            days = 1
        return now + timedelta(days=days)

    def progress_snapshot(self, user: User) -> ProgressSnapshot:
        items = self.db.query(LearningItem).filter(LearningItem.user_id == user.id).all()
        sessions = self.db.query(TutorSession).filter(TutorSession.user_id == user.id, TutorSession.status == "completed").count()
        due = len(self.due_items(user, limit=100))

        def metric(skill: str) -> ProgressMetric:
            relevant = [item for item in items if item.source_skill == skill]
            evidence = sum(item.evidence_count for item in relevant)
            if not relevant:
                return ProgressMetric(skill=skill, mastery_score=None, confidence=0, evidence_count=0, trend="insufficient_evidence")
            score = ScoringService.average([item.mastery_score for item in relevant])
            confidence = sum(item.confidence * item.evidence_count for item in relevant) / max(1, evidence)
            if evidence < 3:
                trend = "starting"
            elif any(item.status in {"relapsed", "new"} for item in relevant):
                trend = "needs_review"
            elif score is not None and score >= 70:
                trend = "improving"
            else:
                trend = "stable"
            return ProgressMetric(
                skill=skill,
                mastery_score=score,
                confidence=round(confidence, 3),
                evidence_count=evidence,
                trend=trend,
            )

        total_evidence = sum(item.evidence_count for item in items)
        return ProgressSnapshot(
            cefr_level=ScoringService.normalize_cefr(user.level),
            cefr_confidence=min(0.95, total_evidence / 20) if total_evidence else 0,
            speaking=metric("speaking"),
            reading=metric("reading"),
            due_reviews=due,
            total_sessions=sessions,
            generated_at=datetime.now(UTC).replace(tzinfo=None),
        )
