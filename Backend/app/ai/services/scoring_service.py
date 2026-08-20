"""Deterministic scoring helpers; model opinions do not bypass these bounds."""

import re
from difflib import SequenceMatcher


class ScoringService:
    @staticmethod
    def clamp(value: int | float, low: int = 0, high: int = 100) -> int:
        return max(low, min(high, round(value)))

    @staticmethod
    def normalize_text(value: str) -> str:
        return " ".join(re.findall(r"[a-z0-9']+", value.lower()))

    @classmethod
    def similarity(cls, left: str, right: str) -> int:
        left_normalized = cls.normalize_text(left)
        right_normalized = cls.normalize_text(right)
        if not left_normalized or not right_normalized:
            return 0
        return cls.clamp(SequenceMatcher(None, left_normalized, right_normalized).ratio() * 100)

    @staticmethod
    def normalize_cefr(value: str | None) -> str:
        normalized = (value or "").strip().upper()
        for level in ("A1", "A2", "B1", "B2", "C1", "C2"):
            if normalized.startswith(level):
                return level
        return "A1"

    @classmethod
    def average(cls, values: list[int | None]) -> int | None:
        present = [value for value in values if value is not None]
        return cls.clamp(sum(present) / len(present)) if present else None
