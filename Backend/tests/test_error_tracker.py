"""
Tests for the error tracking service.
Tests the error detection patterns and logic.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.error_tracker import detect_errors, COMMON_ERRORS


class TestErrorDetection:
    """Test error detection functionality."""

    def test_detect_grammar_error_i_am_go(self):
        """Test detection of 'I am go' -> 'I am going'."""
        errors = detect_errors("I am go to school")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == "i am go"
        assert errors[0]["correct_text"] == "I am going"
        assert errors[0]["error_type"] == "grammar"

    def test_detect_grammar_error_he_go(self):
        """Test detection of 'he go' -> 'he goes'."""
        errors = detect_errors("He go to work every day")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == "he go"
        assert errors[0]["correct_text"] == "he goes"
        assert errors[0]["error_type"] == "grammar"

    def test_detect_grammar_error_she_go(self):
        """Test detection of 'she go' -> 'she goes'."""
        errors = detect_errors("She go to the store")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == "she go"
        assert errors[0]["correct_text"] == "she goes"

    def test_detect_grammar_error_it_go(self):
        """Test detection of 'it go' -> 'it goes'."""
        errors = detect_errors("It go very fast")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == "it go"
        assert errors[0]["correct_text"] == "it goes"

    def test_detect_grammar_error_have_breakfast(self):
        """Test detection of 'have a breakfast' -> 'have breakfast'."""
        errors = detect_errors("I have a breakfast in the morning")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == "have a breakfast"
        assert errors[0]["correct_text"] == "have breakfast"

    def test_detect_grammar_error_more_better(self):
        """Test detection of 'more better' -> 'better'."""
        errors = detect_errors("This is more better than that")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == " more better"
        assert errors[0]["correct_text"] == "better"

    def test_detect_grammar_error_should_to(self):
        """Test detection of 'should to' -> 'should'."""
        errors = detect_errors("You should to study harder")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == " should to"
        assert errors[0]["correct_text"] == "should"

    def test_detect_grammar_error_go_home(self):
        """Test detection of 'go to home' -> 'go home'."""
        errors = detect_errors("Let me go to home now")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == "go to home"
        assert errors[0]["correct_text"] == "go home"

    def test_detect_vocabulary_error_very_delicious(self):
        """Test detection of 'very delicious' -> 'delicious'."""
        errors = detect_errors("The food is very delicious")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == "very delicious"
        assert errors[0]["correct_text"] == "delicious"
        assert errors[0]["error_type"] == "vocabulary"

    def test_detect_vocabulary_error_advices(self):
        """Test detection of 'advices' -> 'advice'."""
        errors = detect_errors("He gave me some advices")
        
        assert len(errors) == 1
        assert errors[0]["wrong_text"] == "advices"
        assert errors[0]["correct_text"] == "advice"
        assert errors[0]["error_type"] == "vocabulary"

    def test_no_errors_in_correct_text(self):
        """Test that correct text produces no errors."""
        errors = detect_errors("I am going to school every day")
        
        assert len(errors) == 0

    def test_multiple_errors_same_text(self):
        """Test detection of multiple errors in one text."""
        errors = detect_errors("I am go to home and he go to work")
        
        assert len(errors) >= 2
        error_types = [e["error_type"] for e in errors]
        assert "grammar" in error_types

    def test_case_insensitive_detection(self):
        """Test that error detection is case-insensitive."""
        errors_lower = detect_errors("i am go")
        errors_upper = detect_errors("I AM GO")
        
        assert len(errors_lower) == len(errors_upper)
        assert errors_lower[0]["correct_text"] == errors_upper[0]["correct_text"]

    def test_empty_text_returns_no_errors(self):
        """Test that empty text returns no errors."""
        errors = detect_errors("")
        
        assert len(errors) == 0

    def test_error_has_required_fields(self):
        """Test that error dict has all required fields."""
        errors = detect_errors("I am go")
        
        assert len(errors) > 0
        error = errors[0]
        
        required_fields = ["wrong_text", "correct_text", "error_type", "explanation"]
        for field in required_fields:
            assert field in error
            assert error[field] is not None

    def test_common_errors_have_valid_structure(self):
        """Test that COMMON_ERRORS list has valid structure."""
        required_keys = ["pattern", "correct", "type", "explanation"]
        
        for error_def in COMMON_ERRORS:
            for key in required_keys:
                assert key in error_def
                assert error_def[key] is not None

