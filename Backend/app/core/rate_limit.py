"""Simple in-memory rate limiting middleware.

Designed to be swappable: replace ``RateLimiter`` with a Redis-backed
implementation (same ``check`` interface) when running multiple workers.

Paths are grouped into buckets with independent limits per client IP.
"""

import threading
import time
from collections import defaultdict, deque

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from .config import settings


class RateLimiter:
    """Sliding-window counter, one deque of timestamps per (bucket, client)."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._hits: dict[tuple[str, str], deque[float]] = defaultdict(deque)

    def check(self, bucket: str, client: str, limit: int, period: int) -> bool:
        """Return True if the request is allowed."""
        now = time.monotonic()
        key = (bucket, client)
        with self._lock:
            hits = self._hits[key]
            cutoff = now - period
            while hits and hits[0] < cutoff:
                hits.popleft()
            if len(hits) >= limit:
                return False
            hits.append(now)
            # Opportunistic cleanup to keep memory bounded.
            if len(self._hits) > 10_000:
                for k in [k for k, v in self._hits.items() if not v]:
                    del self._hits[k]
            return True


# (bucket_name, path_prefix, limit, period)
_RULES: list[tuple[str, str, int, int]] = [
    # Strict: auth endpoints (prevent brute force / code guessing)
    ("auth", "/api/v1/auth/", settings.RATE_LIMIT_AUTH_REQUESTS, settings.RATE_LIMIT_PERIOD),
    # General: endpoints that call paid external APIs
    ("chat", "/api/v1/chat", settings.RATE_LIMIT_REQUESTS, settings.RATE_LIMIT_PERIOD),
    ("tts", "/api/v1/tts", settings.RATE_LIMIT_REQUESTS, settings.RATE_LIMIT_PERIOD),
    ("journal", "/api/v1/journal/analyze", settings.RATE_LIMIT_REQUESTS, settings.RATE_LIMIT_PERIOD),
    ("assessment", "/api/v1/assessment/", settings.RATE_LIMIT_REQUESTS, settings.RATE_LIMIT_PERIOD),
    ("suggestion", "/api/v1/suggestion/", settings.RATE_LIMIT_REQUESTS, settings.RATE_LIMIT_PERIOD),
]

limiter = RateLimiter()


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        path = request.url.path
        for bucket, prefix, limit, period in _RULES:
            if path.startswith(prefix):
                client = request.client.host if request.client else "unknown"
                if not limiter.check(bucket, client, limit, period):
                    return JSONResponse(
                        status_code=429,
                        content={"detail": "عدد الطلبات كبير جدًا، حاول بعد قليل."},
                        headers={"Retry-After": str(period)},
                    )
                break
        return await call_next(request)
