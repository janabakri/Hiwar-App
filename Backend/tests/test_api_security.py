"""Integration tests for authentication, authorization, and chat ownership."""

from pathlib import Path
import sys

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings
from app.core.database import Base, get_db
from app.main import app
from app.models.user import User
from app.models.conversation import Conversation, Message
from app.models.error import UserError
from app.models.journal import JournalEntry
from app.api.v1.profile import _verification_digest


def _client():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSession = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(engine)

    def override_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_db
    settings.SECRET_KEY = "test-secret-key-with-at-least-32-characters"
    return TestClient(app), TestingSession


def _register(client: TestClient, session_factory, email: str):
    response = client.post("/api/v1/auth/sign-up", json={
        "name": "Test User", "email": email, "password": "StrongPassword123!"
    })
    assert response.status_code == 200
    with session_factory() as db:
        user = db.query(User).filter(User.email == email).one()
        code = "123456"
        user.verification_code = _verification_digest(email, code)
        user.email_verified = False
        db.commit()
    verified = client.post("/api/v1/auth/verify-email", json={"email": email, "code": code})
    assert verified.status_code == 200
    return verified.json()


def test_protected_endpoint_requires_token():
    client, _ = _client()
    assert client.get("/api/v1/profile/unknown").status_code == 401


def test_user_cannot_read_or_write_another_profile():
    client, sessions = _client()
    first = _register(client, sessions, "one@gmail.com")
    second = _register(client, sessions, "two@gmail.com")
    headers = {"Authorization": f"Bearer {first['access_token']}"}
    assert client.get(f"/api/v1/profile/{second['user_id']}", headers=headers).status_code == 403
    assert client.put("/api/v1/profile", headers=headers, json={
        "user_id": second["user_id"], "name": "Attacker"
    }).status_code == 403


def test_authenticated_chat_persists_only_for_owner():
    client, sessions = _client()
    account = _register(client, sessions, "chat@gmail.com")
    headers = {"Authorization": f"Bearer {account['access_token']}"}
    response = client.post("/api/v1/chat", headers=headers, json={
        "user_id": account["user_id"], "message": "I am go to school"
    })
    assert response.status_code == 200
    assert response.json()["corrections"]
    forbidden = client.post("/api/v1/chat", headers=headers, json={
        "user_id": "someone-else", "message": "Hello"
    })
    assert forbidden.status_code == 403


def test_delete_account_removes_only_owned_data():
    client, sessions = _client()
    account = _register(client, sessions, "delete@gmail.com")
    other = _register(client, sessions, "keep@gmail.com")

    with sessions() as db:
        owner = db.query(User).filter(User.user_id == account["user_id"]).one()
        conversation = Conversation(user_id=owner.id)
        conversation.messages.append(Message(role="user", content="Hello"))
        db.add(conversation)
        db.add(UserError(user_id=owner.id, error_type="grammar", wrong_text="I go", correct_text="I went"))
        db.add(JournalEntry(user_id=owner.id, original_text="I go yesterday", corrected_text="I went yesterday", follow_up_question="What did you do next?"))
        db.commit()

    response = client.delete(
        "/api/v1/account",
        headers={"Authorization": f"Bearer {account['access_token']}"},
    )
    assert response.status_code == 204
    assert response.content == b""

    with sessions() as db:
        assert db.query(User).filter(User.user_id == account["user_id"]).count() == 0
        assert db.query(Conversation).count() == 0
        assert db.query(Message).count() == 0
        assert db.query(UserError).count() == 0
        assert db.query(JournalEntry).count() == 0
        assert db.query(User).filter(User.user_id == other["user_id"]).count() == 1


def test_manual_sign_in_is_disabled_by_default():
    client, _ = _client()
    settings.ALLOW_MANUAL_AUTH = False
    response = client.post("/api/v1/auth/sign-in", json={
        "user_id": "spoofed", "name": "Spoofed", "auth_provider": "manual"
    })
    assert response.status_code == 400

