"""Select the next useful activity from real learner evidence."""

from sqlalchemy.orm import Session

from ...models.user import User
from ..contracts.memory import LearningPlan
from ..contracts.speaking import SpeakingSessionPlan
from .memory_service import MemoryService
from .scoring_service import ScoringService


class CurriculumService:
    def __init__(self, db: Session):
        self.memory = MemoryService(db)

    def speaking_plan(
        self,
        user: User,
        *,
        mode: str,
        requested_topic: str | None,
        requested_goal: str | None,
    ) -> SpeakingSessionPlan:
        context = self.memory.profile_context(user, source_skill="speaking")
        recent = context["recent_learning_items"]
        target_codes = [item["skill_code"] for item in recent[:2]]
        reason = (user.learning_reason or "daily life").lower()
        if requested_topic:
            topic = requested_topic.strip()
        elif "عمل" in reason or "work" in reason or "وظ" in reason:
            topic = "A conversation at work"
        elif "سفر" in reason or "travel" in reason:
            topic = "Handling a travel situation"
        else:
            topic = "A useful daily-life conversation"

        if requested_goal:
            goal = requested_goal.strip()
        elif recent:
            goal = f"Use {recent[0]['label']} correctly in a natural conversation"
        else:
            goal = "Speak in complete, clear sentences and ask one follow-up question"

        opening_by_level = {
            "A1": "Let's start simply. What did you do today?",
            "A2": "Tell me about something useful you did this week.",
            "B1": "Tell me about a recent situation and explain what you learned from it.",
            "B2": "Describe a recent challenge and explain how you handled it.",
            "C1": "Describe a recent decision and defend the reasoning behind it.",
            "C2": "Explain a nuanced issue you encountered and evaluate the alternatives.",
        }
        level = ScoringService.normalize_cefr(user.level)
        safe_mode = mode if mode in {"conversation", "coach", "scenario", "assessment"} else "conversation"
        return SpeakingSessionPlan(
            cefr_level=level,
            mode=safe_mode,
            topic=topic,
            goal=goal,
            opening_prompt=opening_by_level[level],
            target_skill_codes=target_codes,
            correction_limit=2,
        )

    def today(self, user: User) -> LearningPlan:
        due = self.memory.due_items(user)
        if due:
            first = due[0]
            return LearningPlan(
                recommended_skill=first.source_skill if first.source_skill in {"speaking", "reading"} else "speaking",
                goal=f"Review: {first.label}",
                reason_ar=f"هذه النقطة موعد مراجعتها الآن، وعندنا عليها {first.evidence_count} دليل.",
                due_review_count=len(due),
                suggested_minutes=min(20, user.daily_minutes or 15),
            )
        focus = (user.focus_skills or "").lower()
        skill = "reading" if "reading" in focus and "speaking" not in focus else "speaking"
        return LearningPlan(
            recommended_skill=skill,
            goal="Build reliable evidence for your current level",
            reason_ar="لا توجد مراجعات مستحقة بعد؛ سنجمع أدلة جديدة من نشاط قصير مناسب لمستواك.",
            due_review_count=0,
            suggested_minutes=min(20, user.daily_minutes or 15),
        )
