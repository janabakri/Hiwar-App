"""HTTP-level checks for authenticated tutor routes and user isolation."""

from fastapi import FastAPI
from fastapi.testclient import TestClient
from jose import jwt
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.v1 import learning_plan, reading, speaking
from app.core.config import settings
from app.core.database import Base, get_db
from app.models.user import User


@pytest.fixture
def api():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = session_factory()
    first = User(user_id="api-first", name="First", level="A2")
    second = User(user_id="api-second", name="Second", level="A1")
    db.add_all([first, second])
    db.commit()

    app = FastAPI()
    app.include_router(speaking.router, prefix="/api/v1")
    app.include_router(reading.router, prefix="/api/v1")
    app.include_router(learning_plan.router, prefix="/api/v1")

    def override_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = override_db
    with TestClient(app) as client:
        yield client

    db.close()
    Base.metadata.drop_all(engine)


def _headers(user_id: str) -> dict[str, str]:
    token = jwt.encode({"sub": user_id}, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return {"Authorization": f"Bearer {token}"}


def test_tutor_routes_require_authentication(api):
    response = api.get("/api/v1/progress")
    assert response.status_code == 401


def test_speaking_session_is_private_to_its_owner(api):
    started = api.post(
        "/api/v1/speaking/sessions",
        headers=_headers("api-first"),
        json={"mode": "conversation", "topic": None, "goal": None},
    )
    assert started.status_code == 200
    session_id = started.json()["session_id"]

    forbidden = api.post(
        f"/api/v1/speaking/sessions/{session_id}/turns",
        headers=_headers("api-second"),
        json={"transcript": "I work every day."},
    )
    assert forbidden.status_code == 404

    accepted = api.post(
        f"/api/v1/speaking/sessions/{session_id}/turns",
        headers=_headers("api-first"),
        json={"transcript": "I work every day."},
    )
    assert accepted.status_code == 200
    assert accepted.json()["analysis"]["scores"]["pronunciation"] is None


def test_reading_and_progress_work_through_the_public_api(api):
    headers = _headers("api-first")
    started = api.post(
        "/api/v1/reading/sessions",
        headers=headers,
        json={"level": "A2", "topic": "daily practice", "source_text": None},
    )
    assert started.status_code == 200
    payload = started.json()
    first_question = payload["lesson"]["questions"][0]
    assert "correct_answer" not in first_question
    assert "explanation_ar" not in first_question

    answered = api.post(
        f"/api/v1/reading/sessions/{payload['session_id']}/answers",
        headers=headers,
        json={
            "question_id": first_question["id"],
            "answer": first_question["options"][0],
        },
    )
    assert answered.status_code == 200
    assert answered.json()["analysis"]["correct"] is True

    progress = api.get("/api/v1/progress", headers=headers)
    assert progress.status_code == 200
    assert progress.json()["reading"]["evidence_count"] == 1
