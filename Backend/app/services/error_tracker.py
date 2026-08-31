"""
Error detection and tracking service.
"""

import re
from typing import List, Dict

# Common error patterns
COMMON_ERRORS = [
    {
        "pattern": r"\b(I am go)\b",
        "correct": "I am going",
        "type": "grammar",
        "explanation": "After 'am', use verb + ing"
    },
    {
        "pattern": r"\b(he|she|it) go\b",
        "correct": r"\1 goes",
        "type": "grammar",
        "explanation": "With he/she/it, add 's' to verb"
    },
    {
        "pattern": r"\b(have a breakfast)\b",
        "correct": "have breakfast",
        "type": "grammar",
        "explanation": "Don't use 'a' with meals"
    },
    {
        "pattern": r"\b( more better)\b",
        "correct": "better",
        "type": "grammar",
        "explanation": "'Better' means 'more good'"
    },
    {
        "pattern": r"\b( should to)\b",
        "correct": "should",
        "type": "grammar",
        "explanation": "After 'should', use verb directly"
    },
    {
        "pattern": r"\b(go to home)\b",
        "correct": "go home",
        "type": "grammar",
        "explanation": "Don't use 'to' with 'home'"
    },
    {
        "pattern": r"\b(very delicious)\b",
        "correct": "delicious",
        "type": "vocabulary",
        "explanation": "'Delicious' means 'very tasty'"
    },
    {
        "pattern": r"\b(advices)\b",
        "correct": "advice",
        "type": "vocabulary",
        "explanation": "'Advice' is uncountable"
    },
]

def detect_errors(text: str) -> List[Dict]:
    """Detect errors in user text."""
    errors = []
    text_lower = text.lower()

    for error in COMMON_ERRORS:
        match = re.search(error["pattern"], text_lower, re.IGNORECASE)
        if match:
            wrong_text = match.group(0)

            # Fix the text
            if r"\1" in error["correct"]:
                groups = match.groups()
                if groups:
                    correct_text = error["correct"].replace(r"\1", groups[0])
                else:
                    correct_text = error["correct"]
            else:
                correct_text = error["correct"]

            errors.append({
                "wrong_text": wrong_text,
                "correct_text": correct_text,
                "error_type": error["type"],
                "explanation": error["explanation"]
            })

    return errors
