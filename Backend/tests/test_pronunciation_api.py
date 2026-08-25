"""HTTP checks for secure pronunciation evidence ingestion."""

from fastapi import FastAPI
from fastapi.testclient import TestClient
from jose import jwt
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.ai.contracts.pronunciation import PronunciationAssessmentResult, PronunciationWordScore
from app.ai.providers.base import ProviderUsage
from app.api.v1 import pronunciation, speaking
from app.core.config import settings
from app.core.database import Base, get_db
from app.models.learning import AIUsageEvent, LearningEvent, LearningItem
from app.models.user import User


class FakePronunciationProvider:
    available = True

    async def assess(self, **_kwargs):
        return (
            PronunciationAssessmentResult(
                locale="en-US",
                reference_text="Good morning.",
                recognized_text="Good morning.",
                pronunciation_score=72,
                accuracy_score=70,
                fluency_score=82,
                completeness_score=100,
                prosody_score=None,
                reference_match_score=100,
                reliable=True,
                words=[
                    PronunciationWordScore(
                        word="Good",
                        accuracy_score=55,
                        error_type="Mispronunciation",
                    )
                ],
                audio_retained=False,
            ),
            ProviderUsage(
                provider="azure_speech",
                model="pronunciation-assessment",
                input_tokens=0,
                output_tokens=0,
                duration_ms=5,
            ),
        )


class UnreliablePronunciationProvider(FakePronunciationProvider):
    async def assess(self, **_kwargs):
        result, usage = await super().assess()
        return result.model_copy(
            update={
                "recognized_text": "Something unrelated.",
                "reference_match_score": 20,
                "reliable": False,
                "warning_ar": "الكلام لا يطابق النص المرجعي.",
            }
        ), usage


@pytest.fixture
def api(monkeypatch):
    monkeypatch.setattr(settings, "SECRET_KEY", "test-only-secret-key-for-pronunciation-api")
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = session_factory()
    db.add(User(user_id="pronunciation-user", name="Pronunciation User", level="A2"))
    db.commit()

    app = FastAPI()
    app.include_router(speaking.router, prefix="/api/v1")
    app.include_router(pronunciation.router, prefix="/api/v1")

    def override_db():
        yield db

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[pronunciation.get_pronunciation_provider] = FakePronunciationProvider
    with TestClient(app) as client:
        yield client, db

    db.close()
    Base.metadata.drop_all(engine)


def _headers() -> dict[str, str]:
    token = jwt.encode(
        {"sub": "pronunciation-user"},
        settings.SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )
    return {"Authorization": f"Bearer {token}"}


def test_pronunciation_requires_authentication(api):
    client, _db = api
    response = client.post(
        "/api/v1/pronunciation/assess",
        data={"reference_text": "Good morning."},
        files={"audio": ("attempt.wav", b"audio", "audio/wav")},
    )
    assert response.status_code == 401


def test_pronunciation_records_audio_evidence_but_not_audio_bytes(api):
    client, db = api
    started = client.post(
        "/api/v1/speaking/sessions",
        headers=_headers(),
        json={"mode": "conversation", "topic": "daily life", "goal": None},
    )
    assert started.status_code == 200

    response = client.post(
        "/api/v1/pronunciation/assess",
        headers=_headers(),
        data={
            "reference_text": "Good morning.",
            "source_skill": "speaking",
            "session_id": started.json()["session_id"],
        },
        files={"audio": ("attempt.wav", b"temporary audio bytes", "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json()["audio_retained"] is False
    item = db.query(LearningItem).filter(LearningItem.skill_type == "pronunciation").one()
    assert item.skill_code == "pronunciation_good"
    event = db.query(LearningEvent).filter(LearningEvent.skill_code == "pronunciation_good").one()
    assert event.evidence["audio_retained"] is False
    assert "temporary audio bytes" not in str(event.evidence)
    usage = db.query(AIUsageEvent).filter(AIUsageEvent.feature == "pronunciation_assessment").one()
    assert usage.provider == "azure_speech"


def test_pronunciation_returns_503_until_key_is_configured(api):
    client, _db = api
    client.app.dependency_overrides[pronunciation.get_pronunciation_provider] = lambda: None
    response = client.post(
        "/api/v1/pronunciation/assess",
        headers=_headers(),
        data={"reference_text": "Good morning."},
        files={"audio": ("attempt.wav", b"audio", "audio/wav")},
    )
    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "provider_not_configured"


def test_unreliable_pronunciation_never_updates_learning_memory(api):
    client, db = api
    started = client.post(
        "/api/v1/speaking/sessions",
        headers=_headers(),
        json={"mode": "conversation", "topic": "daily life", "goal": None},
    )
    client.app.dependency_overrides[pronunciation.get_pronunciation_provider] = (
        UnreliablePronunciationProvider
    )

    response = client.post(
        "/api/v1/pronunciation/assess",
        headers=_headers(),
        data={
            "reference_text": "Good morning.",
            "source_skill": "speaking",
            "session_id": started.json()["session_id"],
        },
        files={"audio": ("attempt.wav", b"temporary audio bytes", "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json()["reliable"] is False
    assert db.query(LearningEvent).count() == 0
    assert db.query(LearningItem).count() == 0
    assert db.query(AIUsageEvent).count() == 1
