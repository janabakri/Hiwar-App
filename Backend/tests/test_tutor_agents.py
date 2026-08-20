"""Regression tests for Hiwar's bounded Speaking and Reading agents."""

from datetime import UTC, datetime

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.ai.agents.tutor_orchestrator import TutorOrchestrator
from app.ai.contracts.memory import LearningCandidate
from app.ai.contracts.reading import ReadingLesson
from app.ai.contracts.speaking import FeedbackItem, SpeakingScores, SpeakingTurnAnalysis
from app.ai.providers.openai_text import ProviderUsage, StructuredGeneration
from app.ai.services.memory_service import MemoryService
from app.api.v1.reading import ReadingAnswerRequest
from app.api.v1.speaking import SpeakingRetryRequest, SpeakingTurnRequest
from app.core.database import Base
from app.models.learning import LearningEvent, LearningItem
from app.models.user import User


class OfflineProvider:
    available = False

    def generate_structured(self, **_kwargs):
        return None


class FabricatingProvider:
    available = True

    def generate_structured(self, **_kwargs):
        false_feedback = FeedbackItem(
            type="grammar",
            code="invented_error",
            wrong="I have went there",
            corrected="I have gone there",
            explanation_ar="تصحيح غير موجود في كلام المستخدم",
            confidence=0.99,
        )
        analysis = SpeakingTurnAnalysis(
            meaning_understood=True,
            transcript="ignored",
            assistant_reply="Thanks. What happened next?",
            corrected_utterance="I work every day.",
            natural_alternative="I work every day.",
            priority_feedback=[false_feedback],
            scores=SpeakingScores(
                grammar=90,
                vocabulary=80,
                fluency=80,
                pronunciation=99,
                naturalness=85,
                interactive_communication=80,
            ),
            retry_required=True,
            retry_phrase="I have gone there.",
            memory_candidates=[
                LearningCandidate(
                    skill_code="invented_error",
                    skill_type="grammar",
                    label="invented",
                    explanation_ar="غير موجود",
                    confidence=0.99,
                    mastery_delta=-10,
                )
            ],
            next_action="request_retry",
        )
        return StructuredGeneration(
            value=analysis,
            usage=ProviderUsage(
                provider="test",
                model="fake",
                input_tokens=1,
                output_tokens=1,
                duration_ms=1,
            ),
        )


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    yield session
    session.close()
    Base.metadata.drop_all(engine)


@pytest.fixture
def user(db):
    learner = User(
        user_id="agent-user",
        name="Agent User",
        level="A2",
        learning_reason="English for work",
        focus_skills="Speaking, Reading",
        daily_minutes=15,
    )
    db.add(learner)
    db.commit()
    db.refresh(learner)
    return learner


def orchestrator(db) -> TutorOrchestrator:
    return TutorOrchestrator(db, provider=OfflineProvider())


def test_speaking_session_uses_profile_and_one_goal(db, user):
    session, plan = orchestrator(db).start_speaking(user=user, mode="coach", topic=None, goal=None)

    assert session.skill == "speaking"
    assert plan.mode == "coach"
    assert "work" in plan.topic.lower()
    assert plan.correction_limit == 2
    assert plan.opening_prompt


def test_transcript_only_turn_never_claims_pronunciation(db, user):
    tutor = orchestrator(db)
    session, _ = tutor.start_speaking(user=user, mode="conversation", topic=None, goal=None)

    _, analysis = tutor.speaking_turn(
        user=user,
        session_public_id=session.public_id,
        transcript="I am go to work and he go home",
    )

    assert analysis.scores.pronunciation is None
    assert all(item.type != "pronunciation" for item in analysis.priority_feedback)
    assert len(analysis.priority_feedback) <= 2
    assert analysis.retry_required is True


def test_model_cannot_attach_an_invented_error_to_the_current_turn(db, user):
    tutor = TutorOrchestrator(db, provider=FabricatingProvider())
    session, _ = tutor.start_speaking(user=user, mode="conversation", topic=None, goal=None)

    _, analysis = tutor.speaking_turn(
        user=user,
        session_public_id=session.public_id,
        transcript="I work every day.",
    )

    assert analysis.priority_feedback == []
    assert analysis.memory_candidates == []
    assert analysis.retry_required is False
    assert analysis.scores.pronunciation is None
    assert db.query(LearningItem).count() == 0


def test_retry_records_improvement_and_updates_memory(db, user):
    tutor = orchestrator(db)
    session, _ = tutor.start_speaking(user=user, mode="coach", topic=None, goal=None)
    turn, _ = tutor.speaking_turn(user=user, session_public_id=session.public_id, transcript="I am go to work")

    attempt, retry = tutor.speaking_retry(
        user=user,
        turn_public_id=turn.public_id,
        transcript="I am going to work",
    )

    assert retry.successful is True
    assert retry.improvement > 0
    assert attempt.successful is True
    item = db.query(LearningItem).filter(LearningItem.user_id == user.id).first()
    assert item is not None
    assert item.evidence_count >= 2
    assert item.last_success_at is not None


def test_low_confidence_memory_requires_repeated_evidence(db, user):
    memory = MemoryService(db)
    candidate = LearningCandidate(
        skill_code="possible_article_error",
        skill_type="grammar",
        label="Possible article error",
        explanation_ar="ملاحظة منخفضة الثقة",
        confidence=0.5,
        mastery_delta=-5,
    )

    first = memory.record_candidates(
        user=user,
        session=None,
        candidates=[candidate],
        source_skill="speaking",
        evidence_kind="model_observation",
        evidence={"context": "first"},
    )
    db.commit()
    assert first == []
    assert db.query(LearningEvent).count() == 1
    assert db.query(LearningItem).count() == 0

    second = memory.record_candidates(
        user=user,
        session=None,
        candidates=[candidate],
        source_skill="speaking",
        evidence_kind="model_observation",
        evidence={"context": "second"},
    )
    db.commit()
    assert len(second) == 1
    assert db.query(LearningItem).count() == 1


def test_reading_agent_adapts_lesson_and_records_answers(db, user):
    tutor = orchestrator(db)
    session, material, lesson = tutor.start_reading(
        user=user,
        level="A2",
        topic="work habits",
        source_text=None,
    )

    assert material.cefr_level == "A2"
    assert len(lesson.questions) == 4
    assert {question.type for question in lesson.questions} == {"main_idea", "detail", "inference", "vocabulary"}
    question = lesson.questions[0]
    _, analysis = tutor.reading_answer(
        user=user,
        session_public_id=session.public_id,
        question_id=question.id,
        answer=question.correct_answer,
    )
    assert analysis.correct is True
    assert db.query(LearningItem).filter(LearningItem.source_skill == "reading").count() == 1


def test_session_ownership_is_enforced(db, user):
    tutor = orchestrator(db)
    session, _ = tutor.start_speaking(user=user, mode="conversation", topic=None, goal=None)
    other = User(user_id="other-user", name="Other", level="A1")
    db.add(other)
    db.commit()
    db.refresh(other)

    with pytest.raises(LookupError):
        tutor.speaking_turn(user=other, session_public_id=session.public_id, transcript="Hello")


def test_retry_is_rejected_when_the_turn_has_no_confirmed_correction(db, user):
    tutor = orchestrator(db)
    session, _ = tutor.start_speaking(user=user, mode="conversation", topic=None, goal=None)
    turn, analysis = tutor.speaking_turn(
        user=user,
        session_public_id=session.public_id,
        transcript="I work every day.",
    )
    assert analysis.retry_required is False

    with pytest.raises(ValueError, match="does not require"):
        tutor.speaking_retry(user=user, turn_public_id=turn.public_id, transcript="I work every day.")


def test_retry_stops_after_three_unsuccessful_attempts(db, user):
    tutor = orchestrator(db)
    session, _ = tutor.start_speaking(user=user, mode="coach", topic=None, goal=None)
    turn, _ = tutor.speaking_turn(
        user=user,
        session_public_id=session.public_id,
        transcript="I am go to work",
    )

    outcomes = [
        tutor.speaking_retry(user=user, turn_public_id=turn.public_id, transcript="banana")[1]
        for _ in range(3)
    ]

    assert outcomes[0].next_action == "retry_again"
    assert outcomes[1].next_action == "retry_again"
    assert outcomes[2].next_action == "continue"
    with pytest.raises(ValueError, match="limit"):
        tutor.speaking_retry(user=user, turn_public_id=turn.public_id, transcript="banana")


def test_empty_session_does_not_create_fake_progress(db, user):
    tutor = orchestrator(db)
    session, _ = tutor.start_speaking(user=user, mode="conversation", topic=None, goal=None)

    summary = tutor.finish_speaking(user=user, session_public_id=session.public_id)
    db.refresh(session)

    assert summary.evidence_count == 0
    assert session.status == "abandoned"
    assert tutor.progress(user).total_sessions == 0


def test_reading_contract_rejects_missing_skill_types():
    question = {
        "id": "q1",
        "type": "detail",
        "question": "What happened?",
        "options": ["One", "Two"],
        "correct_answer": "One",
        "explanation_ar": "تفصيل",
    }
    with pytest.raises(ValidationError):
        ReadingLesson.model_validate(
            {
                "title": "Invalid lesson",
                "cefr_level": "A1",
                "topic": "test",
                "passage": "This passage is long enough to pass the minimum length requirement safely.",
                "target_words": [
                    {
                        "word": "passage",
                        "meaning_ar": "نص",
                        "ipa": "",
                        "example": "This is a passage.",
                        "skill_code": "vocab_passage",
                    }
                ],
                "questions": [
                    {**question, "id": "q1"},
                    {**question, "id": "q2"},
                    {**question, "id": "q3"},
                    {**question, "id": "q4"},
                ],
            }
        )


@pytest.mark.parametrize(
    ("contract", "payload"),
    [
        (SpeakingTurnRequest, {"transcript": "   "}),
        (SpeakingRetryRequest, {"transcript": "\n\t"}),
        (ReadingAnswerRequest, {"question_id": "q1", "answer": "   "}),
    ],
)
def test_tutor_requests_reject_whitespace_only_input(contract, payload):
    with pytest.raises(ValidationError):
        contract.model_validate(payload)


def test_progress_reports_insufficient_evidence_instead_of_fake_score(db, user):
    snapshot = orchestrator(db).progress(user)

    assert snapshot.speaking.mastery_score is None
    assert snapshot.reading.mastery_score is None
    assert snapshot.speaking.trend == "insufficient_evidence"
    assert snapshot.cefr_confidence == 0
    assert snapshot.generated_at <= datetime.now(UTC).replace(tzinfo=None)
