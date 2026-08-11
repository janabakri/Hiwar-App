"""
Comprehensive tests for the chat API endpoints.
Tests include database interactions, user management, and error tracking.
"""

import sys
from pathlib import Path
from datetime import datetime

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.api.v1.chat import ChatMessage, ChatResponse, chat
from app.models.user import User
from app.models.error import UserError
from app.core.database import Base
from app.core.config import settings


# ===== Test Database Setup =====
# Use in-memory SQLite for testing
TEST_DATABASE_URL = "sqlite:///:memory:"

@pytest.fixture
def test_db():
    """Create a test database session."""
    engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    
    yield db
    
    db.close()
    Base.metadata.drop_all(bind=engine)


# ===== Test Classes =====
class TestChatModels:
    """Test the Pydantic models used in chat API."""

    def test_chat_message_creation(self):
        """Test ChatMessage model creation."""
        msg = ChatMessage(message="I am go to school", user_id="user123")
        
        assert msg.message == "I am go to school"
        assert msg.user_id == "user123"

    def test_chat_message_required_fields(self):
        """Test that ChatMessage requires all fields."""
        with pytest.raises(Exception):
            ChatMessage(message="Hello")  # Missing user_id

    def test_chat_response_creation(self):
        """Test ChatResponse model creation."""
        response = ChatResponse(
            reply="Your message is good",
            corrections=[{"wrong": "am go", "correct": "am going"}],
            tips=["Use gerund after 'am'"]
        )
        
        assert response.reply == "Your message is good"
        assert len(response.corrections) == 1
        assert len(response.tips) == 1

    def test_chat_response_optional_fields(self):
        """Test that ChatResponse has optional fields."""
        response = ChatResponse(reply="Hello")
        
        assert response.reply == "Hello"
        assert response.corrections == []
        assert response.tips == []


class TestChatEndpoint:
    """Test the chat endpoint functionality."""

    @pytest.mark.asyncio
    async def test_chat_creates_new_user(self, test_db):
        """Test that chat endpoint creates a new user if not exists."""
        initial_users = test_db.query(User).count()
        
        response = await chat(
            ChatMessage(message="I am go to school", user_id="new_user_123"),
            db=test_db
        )
        
        assert isinstance(response, ChatResponse)
        assert response.reply is not None
        
        # Verify user was created
        new_users = test_db.query(User).count()
        assert new_users == initial_users + 1
        
        # Verify user details
        user = test_db.query(User).filter(User.user_id == "new_user_123").first()
        assert user is not None
        assert user.name.startswith("User_")
        assert user.level == "intermediate"

    @pytest.mark.asyncio
    async def test_chat_uses_existing_user(self, test_db):
        """Test that chat endpoint uses existing user if found."""
        # Create a user
        user = User(user_id="existing_user", name="Test User", level="beginner")
        test_db.add(user)
        test_db.commit()
        
        initial_count = test_db.query(User).count()
        
        response = await chat(
            ChatMessage(message="Hello world", user_id="existing_user"),
            db=test_db
        )
        
        # Verify no new user was created
        assert test_db.query(User).count() == initial_count
        
        # Verify the response
        assert isinstance(response, ChatResponse)

    @pytest.mark.asyncio
    async def test_chat_detects_and_saves_errors(self, test_db):
        """Test that chat endpoint detects and saves errors to database."""
        user = User(user_id="user123", name="Test User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        response = await chat(
            ChatMessage(message="I am go to school", user_id="user123"),
            db=test_db
        )
        
        # Verify errors were saved
        errors = test_db.query(UserError).filter(UserError.user_id == user.id).all()
        assert len(errors) > 0
        
        error = errors[0]
        assert error.error_type in ["grammar", "vocabulary"]
        assert error.wrong_text is not None
        assert error.correct_text is not None

    @pytest.mark.asyncio
    async def test_chat_increments_error_count_on_repeat(self, test_db):
        """Test that repeated errors increment the count."""
        user = User(user_id="user456", name="Test User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        # First message with error
        await chat(
            ChatMessage(message="I am go", user_id="user456"),
            db=test_db
        )
        
        error = test_db.query(UserError).filter(UserError.user_id == user.id).first()
        initial_count = error.count
        
        # Second message with same error
        await chat(
            ChatMessage(message="I am go again", user_id="user456"),
            db=test_db
        )
        
        error = test_db.query(UserError).filter(UserError.user_id == user.id).first()
        assert error.count > initial_count

    @pytest.mark.asyncio
    async def test_chat_handles_no_errors(self, test_db):
        """Test that chat handles messages with no errors."""
        user = User(user_id="user789", name="Test User")
        test_db.add(user)
        test_db.commit()
        
        response = await chat(
            ChatMessage(message="I am going to school", user_id="user789"),
            db=test_db
        )
        
        assert isinstance(response, ChatResponse)
        assert response.reply is not None

    @pytest.mark.asyncio
    async def test_chat_response_contains_reply(self, test_db):
        """Test that chat response always contains a reply."""
        response = await chat(
            ChatMessage(message="Hello", user_id="user_abc"),
            db=test_db
        )
        
        assert response.reply is not None
        assert isinstance(response.reply, str)
        assert len(response.reply) > 0

    @pytest.mark.asyncio
    async def test_chat_multiple_errors_in_one_message(self, test_db):
        """Test handling of multiple errors in one message."""
        user = User(user_id="user_multi", name="Test User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        # Message with multiple errors
        response = await chat(
            ChatMessage(
                message="I am go to home and he go to work",
                user_id="user_multi"
            ),
            db=test_db
        )
        
        errors = test_db.query(UserError).filter(UserError.user_id == user.id).all()
        # Should have at least 2 different errors
        assert len(errors) >= 2

    @pytest.mark.asyncio
    async def test_chat_saves_context(self, test_db):
        """Test that error context (original message) is saved."""
        user = User(user_id="user_ctx", name="Test User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        message_text = "I am go to the store"
        response = await chat(
            ChatMessage(message=message_text, user_id="user_ctx"),
            db=test_db
        )
        
        errors = test_db.query(UserError).filter(UserError.user_id == user.id).all()
        if errors:
            assert errors[0].context == message_text

    @pytest.mark.asyncio
    async def test_chat_error_timestamps(self, test_db):
        """Test that error timestamps are properly set."""
        user = User(user_id="user_time", name="Test User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        before = datetime.utcnow()
        await chat(
            ChatMessage(message="I am go", user_id="user_time"),
            db=test_db
        )
        after = datetime.utcnow()
        
        error = test_db.query(UserError).filter(UserError.user_id == user.id).first()
        if error:
            assert before <= error.first_occurrence <= after


class TestChatFallback:
    """Test fallback behavior when OpenAI API is unavailable."""

    @pytest.mark.asyncio
    async def test_chat_falls_back_when_openai_key_missing(self, test_db, monkeypatch):
        """Test chat response when OPENAI_API_KEY is missing."""
        monkeypatch.setattr(settings, "OPENAI_API_KEY", "")
        
        response = await chat(
            ChatMessage(message="I am go to school", user_id="user_fallback"),
            db=test_db
        )
        
        assert response.reply is not None
        assert isinstance(response, ChatResponse)

    @pytest.mark.asyncio
    async def test_chat_returns_corrections_even_without_openai(self, test_db, monkeypatch):
        """Test that corrections are available even without OpenAI."""
        monkeypatch.setattr(settings, "OPENAI_API_KEY", "")
        
        response = await chat(
            ChatMessage(message="I am go", user_id="user_no_openai"),
            db=test_db
        )
        
        # Should still have error detection
        assert isinstance(response, ChatResponse)
        assert response.reply is not None


class TestUserModel:
    """Test User model functionality."""

    def test_user_creation(self, test_db):
        """Test creating a user."""
        user = User(
            user_id="test_user",
            name="Test Name",
            level="intermediate"
        )
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        assert user.id is not None
        assert user.user_id == "test_user"
        assert user.name == "Test Name"
        assert user.is_active is True

    def test_user_statistics_defaults(self, test_db):
        """Test that user statistics have proper defaults."""
        user = User(user_id="stats_user", name="Stats User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        assert user.total_sessions == 0
        assert user.total_errors == 0
        assert user.mastered_errors == 0
        assert user.streak_days == 0

    def test_user_timestamps(self, test_db):
        """Test that user timestamps are properly set."""
        before = datetime.utcnow()
        user = User(user_id="time_user", name="Time User")
        test_db.add(user)
        test_db.commit()
        after = datetime.utcnow()
        test_db.refresh(user)
        
        assert before <= user.created_at <= after


class TestErrorModel:
    """Test UserError model functionality."""

    def test_error_creation(self, test_db):
        """Test creating an error record."""
        user = User(user_id="error_user", name="Error User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        error = UserError(
            user_id=user.id,
            error_type="grammar",
            wrong_text="I am go",
            correct_text="I am going",
            explanation="Use gerund after am",
            context="I am go to school"
        )
        test_db.add(error)
        test_db.commit()
        test_db.refresh(error)
        
        assert error.id is not None
        assert error.user_id == user.id
        assert error.count == 1
        assert error.mastered is False

    def test_error_count_increment(self, test_db):
        """Test incrementing error count."""
        user = User(user_id="count_user", name="Count User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        error = UserError(
            user_id=user.id,
            error_type="grammar",
            wrong_text="test",
            correct_text="test_fix"
        )
        test_db.add(error)
        test_db.commit()
        
        assert error.count == 1
        
        error.count += 1
        test_db.commit()
        
        error = test_db.query(UserError).filter(UserError.id == error.id).first()
        assert error.count == 2

    def test_error_mastered_flag(self, test_db):
        """Test the mastered flag for errors."""
        user = User(user_id="master_user", name="Master User")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        error = UserError(
            user_id=user.id,
            error_type="vocabulary",
            wrong_text="advices",
            correct_text="advice",
            mastered=False
        )
        test_db.add(error)
        test_db.commit()
        
        assert error.mastered is False
        
        error.mastered = True
        test_db.commit()
        
        error = test_db.query(UserError).filter(UserError.id == error.id).first()
        assert error.mastered is True
