"""Shared pytest fixtures.

Resets the in-memory rate limiter before every test so requests made by
earlier tests never consume the auth/general quota of later ones.
"""

from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.rate_limit import limiter


@pytest.fixture(autouse=True)
def _reset_rate_limiter():
    limiter._hits.clear()
    yield
    limiter._hits.clear()
