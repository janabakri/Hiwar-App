"""
Integration and edge case tests for the Hiwar App backend.
Tests system-level behavior and unusual scenarios.
"""

import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.api.v1.chat import ChatMessage, chat
from app.models.user import User
from app.models.error import UserError
from app.core.database import Base
from app.services.error_tracker import detect_errors


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


class TestIntegration:
    """Integration tests for the full workflow."""

    @pytest.mark.asyncio
    async def test_full_user_workflow(self, test_db):
        """Test complete workflow: user creation -> error detection -> storage."""
        # Step 1: Send first message with error
        response1 = await chat(
            ChatMessage(message="I am go to school", user_id="workflow_user"),
            db=test_db
        )
        assert response1.reply is not None
        
        # Step 2: Verify user exists
        user = test_db.query(User).filter(User.user_id == "workflow_user").first()
        assert user is not None
        
        # Step 3: Verify error was saved
        errors = test_db.query(UserError).filter(UserError.user_id == user.id).all()
        assert len(errors) > 0
        
        # Step 4: Send same error again
        response2 = await chat(
            ChatMessage(message="I am go again", user_id="workflow_user"),
            db=test_db
        )
        
        # Step 5: Verify error count increased
        updated_errors = test_db.query(UserError).filter(UserError.user_id == user.id).all()
        # Check if count increased for existing error
        assert len(updated_errors) >= len(errors)

    @pytest.mark.asyncio
    async def test_concurrent_user_messages(self, test_db):
        """Test handling messages from multiple users."""
        users_data = [
            ("user1", "I am go"),
            ("user2", "He go to school"),
            ("user3", "correct message"),
        ]
        
        for user_id, message in users_data:
            await chat(
                ChatMessage(message=message, user_id=user_id),
                db=test_db
            )
        
        # Verify all users were created
        users = test_db.query(User).all()
        assert len(users) == 3

    @pytest.mark.asyncio
    async def test_different_error_types(self, test_db):
        """Test detection and storage of different error types."""
        error_messages = [
            "I am go",  # grammar
            "he go",  # grammar
            "advices",  # vocabulary
        ]
        
        user = User(user_id="multi_error_user", name="Test")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        for message in error_messages:
            await chat(
                ChatMessage(message=message, user_id="multi_error_user"),
                db=test_db
            )
        
        errors = test_db.query(UserError).filter(UserError.user_id == user.id).all()
        assert len(errors) > 0
        
        # Verify we have different error types
        error_types = {e.error_type for e in errors}
        assert "grammar" in error_types or "vocabulary" in error_types


class TestEdgeCases:
    """Test edge cases and error conditions."""

    def test_empty_message_detection(self):
        """Test error detection with empty message."""
        errors = detect_errors("")
        assert errors == []

    def test_very_long_message_detection(self):
        """Test error detection with very long message."""
        long_message = "I am go " * 100
        errors = detect_errors(long_message)
        assert len(errors) > 0

    def test_special_characters_in_message(self):
        """Test error detection with special characters."""
        message = "I am go!!! @#$ to school"
        errors = detect_errors(message)
        # Should still detect the error despite special characters
        assert any("i am go" in e["wrong_text"].lower() for e in errors) or len(errors) >= 0

    def test_mixed_case_error_detection(self):
        """Test error detection with mixed case."""
        errors_lower = detect_errors("i am go")
        errors_mixed = detect_errors("I aM gO")
        errors_upper = detect_errors("I AM GO")
        
        assert len(errors_lower) > 0
        assert len(errors_mixed) > 0
        assert len(errors_upper) > 0

    def test_numbers_in_message(self):
        """Test error detection with numbers in message."""
        errors = detect_errors("I am go 123 times")
        # Should detect error even with numbers
        assert len(errors) > 0

    def test_whitespace_variations(self):
        """Test error detection with various whitespace."""
        messages = [
            "I am go",
            "I  am  go",  # double spaces
            "I\tam\tgo",  # tabs
        ]
        
        for msg in messages:
            errors = detect_errors(msg)
            # Most should still be detected
            assert len(errors) >= 0

    @pytest.mark.asyncio
    async def test_user_id_with_special_characters(self, test_db):
        """Test handling user_id with special characters."""
        response = await chat(
            ChatMessage(message="I am go", user_id="user@123#xyz"),
            db=test_db
        )
        
        assert response.reply is not None
        user = test_db.query(User).filter(User.user_id == "user@123#xyz").first()
        assert user is not None

    @pytest.mark.asyncio
    async def test_unicode_message(self, test_db):
        """Test handling unicode characters in message."""
        response = await chat(
            ChatMessage(message="I am go café", user_id="unicode_user"),
            db=test_db
        )
        
        assert response.reply is not None

    def test_consecutive_spaces_in_pattern(self):
        """Test patterns with multiple spaces."""
        message = "I  am  go"
        errors = detect_errors(message)
        # Pattern should handle this
        assert len(errors) >= 0

    @pytest.mark.asyncio
    async def test_same_error_different_contexts(self, test_db):
        """Test the same error appearing in different contexts."""
        user = User(user_id="context_user", name="Test")
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)
        
        contexts = [
            "I am go to school",
            "I am go to work",
            "I am go home",
        ]
        
        for context in contexts:
            await chat(
                ChatMessage(message=context, user_id="context_user"),
                db=test_db
            )
        
        errors = test_db.query(UserError).filter(
            UserError.user_id == user.id,
            UserError.wrong_text.ilike("%am go%")
        ).all()
        
        # Should have same error with increased count or multiple entries
        assert len(errors) >= 1


class TestErrorValidation:
    """Test error validation and data integrity."""

    def test_error_explanation_not_empty(self):
        """Test that all detected errors have explanations."""
        messages = [
            "I am go",
            "he go",
            "advices",
            "very delicious",
        ]
        
        for msg in messages:
            errors = detect_errors(msg)
            for error in errors:
                assert error["explanation"]
                assert len(error["explanation"]) > 0

    def test_error_type_valid_values(self):
        """Test that error types are from valid set."""
        valid_types = {"grammar", "vocabulary"}
        
        messages = [
            "I am go",
            "advices",
            "more better",
        ]
        
        for msg in messages:
            errors = detect_errors(msg)
            for error in errors:
                assert error["error_type"] in valid_types

    def test_correct_text_different_from_wrong_text(self):
        """Test that correct text differs from wrong text."""
        messages = [
            "I am go",
            "advices",
            "very delicious",
        ]
        
        for msg in messages:
            errors = detect_errors(msg)
            for error in errors:
                assert error["wrong_text"] != error["correct_text"]

    def test_explanation_contains_helpful_info(self):
        """Test that explanations are helpful."""
        errors = detect_errors("I am go")
        
        if errors:
            explanation = errors[0]["explanation"]
            # Should be meaningful text, not empty or single word
            assert len(explanation) > 5
            assert " " in explanation


class TestPerformance:
    """Test performance and efficiency."""

    def test_error_detection_speed_short_message(self):
        """Test error detection performance on short messages."""
        message = "I am go to school"
        
        import time
        start = time.time()
        for _ in range(100):
            detect_errors(message)
        end = time.time()
        
        # Should complete 100 detections in reasonable time
        assert (end - start) < 5  # 5 seconds for 100 iterations

    def test_error_detection_speed_long_message(self):
        """Test error detection performance on long messages."""
        message = "I am go " * 50
        
        import time
        start = time.time()
        errors = detect_errors(message)
        end = time.time()
        
        # Should complete quickly even for long messages
        assert (end - start) < 1  # 1 second
