"""Central, code-governed coordinator for Hiwar's specialist coaches."""

from datetime import UTC, datetime
from time import monotonic

from sqlalchemy import desc
from sqlalchemy.orm import Session

from ...models.learning import (
    AIUsageEvent,
    AgentTrace,
    ReadingAttempt,
    ReadingMaterial,
    SpeakingAttempt,
    SpeakingTurn,
    TutorSession,
)
from ...models.user import User
from ..contracts.memory import LearningCandidate, LearningPlan, ProgressSnapshot
from ..contracts.pronunciation import PronunciationAssessmentResult
from ..contracts.reading import ReadingAnswerAnalysis, ReadingLesson, ReadingSessionSummary
from ..contracts.speaking import (
    RetryAnalysis,
    SpeakingScores,
    SpeakingSessionPlan,
    SpeakingSessionSummary,
    SpeakingTurnAnalysis,
)
from ..providers.base import ProviderUsage, StructuredTextProvider
from ..providers.factory import create_text_provider
from ..services.curriculum_service import CurriculumService
from ..services.memory_service import MemoryService
from ..services.scoring_service import ScoringService
from .reading_coach import ReadingCoach
from .speaking_coach import SpeakingCoach


class TutorOrchestrator:
    def __init__(self, db: Session, provider: StructuredTextProvider | None = None):
        self.db = db
        self.provider = provider or create_text_provider()
        self.memory = MemoryService(db)
        self.curriculum = CurriculumService(db)
        self.speaking = SpeakingCoach(self.provider)
        self.reading = ReadingCoach(self.provider)

    def start_speaking(
        self,
        *,
        user: User,
        mode: str,
        topic: str | None,
        goal: str | None,
    ) -> tuple[TutorSession, SpeakingSessionPlan]:
        started = monotonic()
        plan = self.curriculum.speaking_plan(
            user,
            mode=mode,
            requested_topic=topic,
            requested_goal=goal,
        )
        session = TutorSession(
            user_id=user.id,
            skill="speaking",
            mode=plan.mode,
            goal=plan.goal,
            topic=plan.topic,
            cefr_level=plan.cefr_level,
            status="active",
            context_data={"plan": plan.model_dump(mode="json")},
        )
        self.db.add(session)
        self.db.flush()
        self._trace(session, "speaking_session_started", "ok", started, {"mode": plan.mode, "level": plan.cefr_level})
        self.db.commit()
        self.db.refresh(session)
        return session, plan

    def speaking_turn(
        self,
        *,
        user: User,
        session_public_id: str,
        transcript: str,
    ) -> tuple[SpeakingTurn, SpeakingTurnAnalysis]:
        started = monotonic()
        session = self._session(user, session_public_id, skill="speaking")
        self._require_active(session)
        recent = (
            self.db.query(SpeakingTurn)
            .filter(SpeakingTurn.session_id == session.id)
            .order_by(desc(SpeakingTurn.created_at))
            .limit(4)
            .all()
        )
        analysis, usage = self.speaking.analyze_turn(
            user=user,
            session=session,
            transcript=transcript,
            recent_turns=list(reversed(recent)),
            memory=self.memory,
            audio_evidence=False,
        )
        turn = SpeakingTurn(
            session_id=session.id,
            transcript=transcript,
            assistant_reply=analysis.assistant_reply,
            corrected_utterance=analysis.corrected_utterance,
            natural_alternative=analysis.natural_alternative,
            priority_feedback=[item.model_dump(mode="json") for item in analysis.priority_feedback],
            scores=analysis.scores.model_dump(mode="json"),
            retry_required=analysis.retry_required,
            retry_phrase=analysis.retry_phrase,
            meaning_understood=analysis.meaning_understood,
        )
        self.db.add(turn)
        session.total_turns += 1
        self.db.flush()
        evidence_kind = "rule_confirmed" if usage is None and analysis.memory_candidates else "model_observation"
        self.memory.record_candidates(
            user=user,
            session=session,
            candidates=analysis.memory_candidates,
            source_skill="speaking",
            evidence_kind=evidence_kind,
            evidence={
                "turn_id": turn.public_id,
                "transcript": transcript,
                "feedback_codes": [item.code for item in analysis.priority_feedback],
            },
        )
        self._record_usage(user, session, "speaking_turn", usage)
        self._trace(
            session,
            "speaking_turn_analyzed",
            "ok",
            started,
            {
                "feedback_count": len(analysis.priority_feedback),
                "retry_required": analysis.retry_required,
                "decision_source": usage.provider if usage else "deterministic",
            },
        )
        self.db.commit()
        self.db.refresh(turn)
        return turn, analysis

    def speaking_retry(
        self,
        *,
        user: User,
        turn_public_id: str,
        transcript: str,
    ) -> tuple[SpeakingAttempt, RetryAnalysis]:
        started = monotonic()
        turn = (
            self.db.query(SpeakingTurn)
            .join(TutorSession, TutorSession.id == SpeakingTurn.session_id)
            .filter(SpeakingTurn.public_id == turn_public_id, TutorSession.user_id == user.id)
            .first()
        )
        if turn is None:
            raise LookupError("Speaking turn not found")
        self._require_active(turn.session)
        if not turn.retry_required:
            raise ValueError("This turn does not require a retry")
        attempts = self.db.query(SpeakingAttempt).filter(SpeakingAttempt.turn_id == turn.id).all()
        if any(item.successful for item in attempts):
            raise ValueError("This retry was already completed")
        if len(attempts) >= 3:
            raise ValueError("Retry limit reached")
        analysis = self.speaking.analyze_retry(turn=turn, transcript=transcript)
        attempt_number = len(attempts) + 1
        if attempt_number >= 3 and not analysis.successful:
            analysis = analysis.model_copy(
                update={
                    "feedback_ar": f"سجلنا المحاولة. سنعود إلى الصيغة لاحقًا بدل تكرارها الآن: {turn.retry_phrase}",
                    "next_action": "continue",
                }
            )
        attempt = SpeakingAttempt(
            turn_id=turn.id,
            attempt_number=attempt_number,
            transcript=transcript,
            similarity_score=analysis.similarity_score,
            improvement=analysis.improvement,
            successful=analysis.successful,
            feedback_ar=analysis.feedback_ar,
        )
        self.db.add(attempt)

        feedback = (turn.priority_feedback or [{}])[0]
        code = feedback.get("code") or f"speaking_retry_{turn.public_id}"
        label = f"{feedback.get('wrong', turn.transcript)} → {feedback.get('corrected', turn.retry_phrase)}"
        candidate = LearningCandidate(
            skill_code=code,
            skill_type=feedback.get("type", "grammar") if feedback.get("type") in {"grammar", "vocabulary", "fluency", "naturalness", "communication", "pronunciation"} else "grammar",
            label=label,
            explanation_ar=feedback.get("explanation_ar", analysis.feedback_ar),
            confidence=0.99,
            mastery_delta=15 if analysis.successful else -8,
        )
        self.memory.record_candidates(
            user=user,
            session=turn.session,
            candidates=[candidate],
            source_skill="speaking",
            evidence_kind="retry_success" if analysis.successful else "retry_failure",
            evidence={
                "turn_id": turn.public_id,
                "attempt_number": attempt_number,
                "similarity_score": analysis.similarity_score,
                "improvement": analysis.improvement,
            },
        )
        self._trace(
            turn.session,
            "speaking_retry_scored",
            "ok",
            started,
            {"attempt_number": attempt_number, "successful": analysis.successful},
        )
        self.db.commit()
        self.db.refresh(attempt)
        return attempt, analysis

    def finish_speaking(self, *, user: User, session_public_id: str) -> SpeakingSessionSummary:
        session = self._session(user, session_public_id, skill="speaking")
        if session.status in {"completed", "partial", "abandoned"} and session.summary:
            return SpeakingSessionSummary.model_validate(session.summary)
        turns = self.db.query(SpeakingTurn).filter(SpeakingTurn.session_id == session.id).order_by(SpeakingTurn.created_at).all()
        score_names = ("grammar", "vocabulary", "fluency", "pronunciation", "naturalness", "interactive_communication")
        averages = {
            name: ScoringService.average([turn.scores.get(name) for turn in turns if turn.scores])
            for name in score_names
        }
        successful_retries = sum(1 for turn in turns for attempt in turn.attempts if attempt.successful)
        correction_count = sum(len(turn.priority_feedback or []) for turn in turns)
        achievements: list[str] = []
        if turns:
            achievements.append(f"أكملت {len(turns)} أدوار في محادثة واحدة.")
        if successful_retries:
            achievements.append(f"حسّنت {successful_retries} محاولة بعد التصحيح.")
        if turns and correction_count == 0:
            achievements.append("حافظت على جمل واضحة دون ملاحظات عالية الأولوية.")
        if not achievements:
            achievements.append("أنهيت الجلسة قبل تسجيل إجابة.")

        recent = self.memory.recent_items(user, source_skill="speaking", limit=1)
        focus = recent[0].label if recent else "استخدام جمل كاملة في سياق جديد"
        summary = SpeakingSessionSummary(
            achievements=achievements[:3],
            review_focus=focus,
            evidence_count=len(turns) + sum(len(turn.attempts) for turn in turns),
            average_scores=SpeakingScores(**averages),
            next_activity="review" if recent else "reading",
            message_ar=(
                "انتهت الجلسة. النجاح اللحظي لا يعني إتقانًا دائمًا؛ سنعيد اختبار النقطة لاحقًا."
                if turns
                else "لم نسجل دليل تعلم لأن الجلسة انتهت قبل أول إجابة."
            ),
        )
        session.status = "completed" if turns else "abandoned"
        session.ended_at = datetime.now(UTC).replace(tzinfo=None)
        session.summary = summary.model_dump(mode="json")
        self.db.commit()
        return summary

    def start_reading(
        self,
        *,
        user: User,
        level: str | None,
        topic: str | None,
        source_text: str | None,
    ) -> tuple[TutorSession, ReadingMaterial, ReadingLesson]:
        started = monotonic()
        lesson, usage = self.reading.create_lesson(
            user=user,
            level=level or user.level,
            topic=topic,
            source_text=source_text,
            memory=self.memory,
        )
        material = ReadingMaterial(
            owner_user_id=user.id if source_text else None,
            source_type="user_text" if source_text else "generated",
            title=lesson.title,
            topic=lesson.topic,
            content=lesson.passage,
            cefr_level=lesson.cefr_level,
            target_words=[item.model_dump(mode="json") for item in lesson.target_words],
            questions=[item.model_dump(mode="json") for item in lesson.questions],
        )
        self.db.add(material)
        self.db.flush()
        session = TutorSession(
            user_id=user.id,
            skill="reading",
            mode="lesson",
            goal="Understand the passage and support answers with evidence",
            topic=lesson.topic,
            cefr_level=lesson.cefr_level,
            status="active",
            reading_material_id=material.id,
            context_data={"target_word_codes": [word.skill_code for word in lesson.target_words]},
        )
        self.db.add(session)
        self.db.flush()
        self._record_usage(user, session, "reading_lesson", usage)
        self._trace(
            session,
            "reading_session_started",
            "ok",
            started,
            {"level": lesson.cefr_level, "decision_source": usage.provider if usage else "deterministic"},
        )
        self.db.commit()
        self.db.refresh(session)
        self.db.refresh(material)
        return session, material, lesson

    def reading_answer(
        self,
        *,
        user: User,
        session_public_id: str,
        question_id: str,
        answer: str,
    ) -> tuple[ReadingAttempt, ReadingAnswerAnalysis]:
        started = monotonic()
        session = self._session(user, session_public_id, skill="reading")
        self._require_active(session)
        material = session.reading_material
        if material is None:
            raise LookupError("Reading material not found")
        lesson = ReadingLesson.model_validate(
            {
                "title": material.title,
                "cefr_level": material.cefr_level,
                "topic": material.topic,
                "passage": material.content,
                "target_words": material.target_words,
                "questions": material.questions,
            }
        )
        question = next((item for item in lesson.questions if item.id == question_id), None)
        if question is None:
            raise LookupError("Reading question not found")
        duplicate = self.db.query(ReadingAttempt).filter(ReadingAttempt.session_id == session.id, ReadingAttempt.question_id == question_id).first()
        if duplicate:
            raise ValueError("This question was already answered")
        analysis, usage = self.reading.assess_answer(lesson=lesson, question=question, answer=answer)
        attempt = ReadingAttempt(
            session_id=session.id,
            question_id=question.id,
            question_type=question.type,
            question=question.question,
            user_answer=answer,
            correct_answer=question.correct_answer,
            score=analysis.score,
            is_correct=analysis.correct,
            feedback_ar=analysis.feedback_ar,
            evidence={"evidence": analysis.evidence},
        )
        self.db.add(attempt)
        session.total_turns += 1
        self.db.flush()
        self.memory.record_candidates(
            user=user,
            session=session,
            candidates=analysis.memory_candidates,
            source_skill="reading",
            evidence_kind="reading_answer",
            evidence={"question_id": question.id, "correct": analysis.correct, "score": analysis.score},
        )
        self._record_usage(user, session, "reading_answer", usage)
        answered = self.db.query(ReadingAttempt).filter(ReadingAttempt.session_id == session.id).count()
        if answered >= len(lesson.questions):
            analysis = analysis.model_copy(update={"next_action": "finish"})
        self._trace(
            session,
            "reading_answer_scored",
            "ok",
            started,
            {
                "question_type": question.type,
                "correct": analysis.correct,
                "decision_source": usage.provider if usage else "deterministic",
            },
        )
        self.db.commit()
        self.db.refresh(attempt)
        return attempt, analysis

    def finish_reading(self, *, user: User, session_public_id: str) -> ReadingSessionSummary:
        session = self._session(user, session_public_id, skill="reading")
        if session.status in {"completed", "partial", "abandoned"} and session.summary:
            return ReadingSessionSummary.model_validate(session.summary)
        attempts = self.db.query(ReadingAttempt).filter(ReadingAttempt.session_id == session.id).all()
        correct = sum(1 for item in attempts if item.is_correct)
        score = ScoringService.average([item.score for item in attempts]) or 0
        strengths = []
        types_correct = {item.question_type for item in attempts if item.is_correct}
        labels = {"main_idea": "تحديد الفكرة الرئيسية", "detail": "فهم التفاصيل", "inference": "الاستنتاج", "vocabulary": "فهم المفردات من السياق"}
        strengths.extend(labels[item] for item in ("main_idea", "detail", "inference", "vocabulary") if item in types_correct)
        recent = self.memory.recent_items(user, source_skill="reading", limit=1)
        focus = recent[0].label if recent else "إكمال أسئلة أكثر للحصول على دليل كافٍ"
        summary = ReadingSessionSummary(
            score=score,
            correct_answers=correct,
            total_answers=len(attempts),
            strengths=strengths[:3],
            review_focus=focus,
            next_activity="speaking" if attempts else "reading",
            message_ar=(
                "تم حفظ نتائج الفهم كأدلة تعلم. يمكنك الآن مناقشة فكرة النص في جلسة Speaking."
                if attempts
                else "لم نسجل دليل تعلم لأن الجلسة انتهت قبل أول إجابة."
            ),
        )
        expected_answers = len(session.reading_material.questions) if session.reading_material else 0
        if not attempts:
            session.status = "abandoned"
        elif len(attempts) < expected_answers:
            session.status = "partial"
        else:
            session.status = "completed"
        session.ended_at = datetime.now(UTC).replace(tzinfo=None)
        session.summary = summary.model_dump(mode="json")
        self.db.commit()
        return summary

    def today_plan(self, user: User) -> LearningPlan:
        return self.curriculum.today(user)

    def progress(self, user: User) -> ProgressSnapshot:
        return self.memory.progress_snapshot(user)

    def record_pronunciation_assessment(
        self,
        *,
        user: User,
        source_skill: str,
        session_public_id: str | None,
        result: PronunciationAssessmentResult,
        usage: ProviderUsage,
    ) -> int:
        """Persist scores and learning evidence, never the submitted audio."""
        started = monotonic()
        if source_skill not in {"speaking", "reading"}:
            raise ValueError("source_skill must be speaking or reading")
        session = None
        if session_public_id:
            session = self._session(user, session_public_id, skill=source_skill)
            self._require_active(session)

        accepted_count = 0
        if session is not None and result.reliable:
            weak_words = [
                word
                for word in result.words
                if word.error_type.lower() not in {"none", "insertion"}
                or (word.accuracy_score is not None and word.accuracy_score < 70)
            ]
            weak_words.sort(key=lambda item: item.accuracy_score if item.accuracy_score is not None else -1)
            candidates = [
                LearningCandidate(
                    skill_code=f"pronunciation_{ScoringService.slug(word.word)}"[:140],
                    skill_type="pronunciation",
                    label=f"نطق كلمة {word.word}",
                    explanation_ar=f"تدرّب على نطق كلمة {word.word} داخل جملة قصيرة ثم أعد المحاولة.",
                    # A borderline transcript match is retained as an event,
                    # but cannot enter durable memory after one attempt.
                    confidence=min(0.99, result.reference_match_score / 100),
                    mastery_delta=-8,
                )
                for word in weak_words[:2]
                if ScoringService.slug(word.word)
            ]
            accepted = self.memory.record_candidates(
                user=user,
                session=session,
                candidates=candidates,
                source_skill=source_skill,
                evidence_kind="audio_assessment",
                evidence={
                    "provider": result.provider,
                    "recognized_text": result.recognized_text,
                    "reference_text": result.reference_text,
                    "pronunciation_score": result.pronunciation_score,
                    "accuracy_score": result.accuracy_score,
                    "fluency_score": result.fluency_score,
                    "completeness_score": result.completeness_score,
                    "prosody_score": result.prosody_score,
                    "reference_match_score": result.reference_match_score,
                    "audio_retained": False,
                },
            )
            accepted_count = len(accepted)

        self._record_usage(user, session, "pronunciation_assessment", usage)
        self._trace(
            session,
            "pronunciation_assessed",
            "ok" if result.reliable else "unreliable",
            started,
            {
                "provider": result.provider,
                "source_skill": source_skill,
                "reference_match_score": result.reference_match_score,
                "memory_items": accepted_count,
                "audio_retained": False,
            },
        )
        self.db.commit()
        return accepted_count

    def _session(self, user: User, public_id: str, *, skill: str) -> TutorSession:
        session = (
            self.db.query(TutorSession)
            .filter(
                TutorSession.public_id == public_id,
                TutorSession.user_id == user.id,
                TutorSession.skill == skill,
            )
            .first()
        )
        if session is None:
            raise LookupError(f"{skill.title()} session not found")
        return session

    @staticmethod
    def _require_active(session: TutorSession) -> None:
        if session.status != "active":
            raise ValueError("Session is not active")

    def _record_usage(self, user: User, session: TutorSession | None, feature: str, usage: ProviderUsage | None) -> None:
        if usage is None:
            return
        self.db.add(
            AIUsageEvent(
                user_id=user.id,
                session_id=session.id if session else None,
                feature=feature,
                provider=usage.provider,
                model=usage.model,
                input_tokens=usage.input_tokens,
                output_tokens=usage.output_tokens,
                duration_ms=usage.duration_ms,
                success=True,
            )
        )

    def _trace(self, session: TutorSession | None, step: str, status: str, started: float, details: dict) -> None:
        self.db.add(
            AgentTrace(
                session_id=session.id if session else None,
                step=step,
                status=status,
                duration_ms=max(0, round((monotonic() - started) * 1000)),
                details=details,
            )
        )
