# Hiwar App Test Suite

## Overview
Comprehensive test suite for the Hiwar App backend using pytest and pytest-asyncio.

## Test Files

### 1. **test_error_tracker.py** ✅
Tests for the error detection service (`app/services/error_tracker.py`)

**Coverage:**
- Grammar error detection (i am go, he go, she go, it go, have a breakfast, etc.)
- Vocabulary error detection (advices, very delicious)
- Case-insensitive detection
- Multiple errors in single text
- Error validation (required fields, error types, explanations)
- Edge cases (empty text, correct text)

**Total Tests:** 16
**Status:** All passing ✅

```bash
pytest tests/test_error_tracker.py -v
```

### 2. **test_chat_comprehensive.py**
Comprehensive tests for the chat API endpoints and database models

**Coverage:**
- **Chat Models:** ChatMessage and ChatResponse validation
- **Chat Endpoint:**
  - User creation and retrieval
  - Error detection and storage
  - Error count incrementation
  - Multiple errors handling
  - Context saving
  - Timestamp management
  - Fallback behavior without OpenAI API
- **User Model:** Creation, statistics, timestamps
- **Error Model:** Creation, count increment, mastered flag

**Test Classes:**
- `TestChatModels` - Pydantic model validation
- `TestChatEndpoint` - API endpoint functionality  
- `TestChatFallback` - Fallback scenarios
- `TestUserModel` - User model operations
- `TestErrorModel` - Error model operations

### 3. **test_integration.py**
Integration and edge case tests

**Coverage:**
- Full workflow testing (user creation → error detection → storage)
- Concurrent user handling
- Different error types in one session
- Edge cases:
  - Empty messages
  - Very long messages
  - Special characters
  - Mixed case
  - Numbers in messages
  - Unicode characters
  - User IDs with special characters
- Error validation (explanations, types, correctness)
- Performance testing

**Test Classes:**
- `TestIntegration` - Full workflow tests
- `TestEdgeCases` - Unusual input scenarios
- `TestErrorValidation` - Error data integrity
- `TestPerformance` - Speed and efficiency

## Running Tests

### Run all tests
```bash
pytest tests/ -v
```

### Run specific test file
```bash
pytest tests/test_error_tracker.py -v
pytest tests/test_chat_comprehensive.py -v
pytest tests/test_integration.py -v
```

### Run specific test class
```bash
pytest tests/test_error_tracker.py::TestErrorDetection -v
```

### Run specific test
```bash
pytest tests/test_error_tracker.py::TestErrorDetection::test_detect_grammar_error_i_am_go -v
```

### Run with coverage report
```bash
pytest tests/ --cov=app --cov-report=html
```

## Test Database
All database tests use an in-memory SQLite database (`sqlite:///:memory:`) to ensure:
- Isolation between tests
- Fast execution
- No side effects
- Easy cleanup

## Dependencies
- pytest==7.4.3
- pytest-asyncio==0.21.1
- sqlalchemy==2.0.23
- fastapi==0.104.1
- pydantic==2.5.0

## Installation
```bash
pip install -r requirements.txt
```

## Current Test Status

| Test File | Tests | Status |
|-----------|-------|--------|
| test_error_tracker.py | 16 | ✅ Passing |
| test_chat_comprehensive.py | ~30 | ⏳ Requires full dependencies |
| test_integration.py | ~20 | ⏳ Requires full dependencies |

## Key Features of the Test Suite

✅ **Comprehensive Coverage**
- Models, services, and endpoints
- Happy path and edge cases
- Error scenarios and fallbacks

✅ **Isolated Testing**
- In-memory database for fast tests
- No external dependencies needed
- Proper fixture setup and teardown

✅ **Async Support**
- Proper async/await testing
- pytest-asyncio configuration
- Handles both sync and async code

✅ **Clear Organization**
- Tests grouped by functionality
- Descriptive test names
- Docstrings for clarity

## Testing Best Practices

1. **Test Independence:** Each test is independent and can run in any order
2. **Clear Assertions:** Each test has clear assertions about expected behavior
3. **Comprehensive Docstrings:** Every test has a docstring explaining what it tests
4. **Mock External Services:** OpenAI API and other external services are mocked
5. **Database Fixtures:** Fresh database for each test

## Future Improvements

- Add more edge case tests
- Implement performance benchmarks
- Add API endpoint tests with TestClient
- Test error recovery scenarios
- Add database migration tests
- Implement CI/CD integration (GitHub Actions, etc.)

## Debugging Tests

To run tests with debugging output:
```bash
pytest tests/ -v -s
```

The `-s` flag shows print statements and logging output.

For more verbose error information:
```bash
pytest tests/ -v --tb=long
```

## Contributing

When adding new features:
1. Write tests first (TDD approach)
2. Run tests to ensure they fail initially
3. Implement the feature
4. Run tests again to ensure they pass
5. Add any edge case tests as needed

