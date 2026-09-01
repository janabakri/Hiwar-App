"""
Hiwar App - Main Server
"""

import logging
import os
from logging.handlers import RotatingFileHandler

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .core.config import settings
from .core.database import engine, Base
from .core.migrations import ensure_user_profile_columns
from .api.v1 import chat, profile, assessment, journal, conversations, tts
from .models import conversation  # noqa: F401  # register Conversation before create_all
from .models import journal as journal_model  # noqa: F401  # register JournalEntry before create_all

# Logging: use LOG_FILE/LOG_LEVEL from settings instead of bare print().
def _configure_logging() -> None:
    level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO)
    handlers: list[logging.Handler] = [logging.StreamHandler()]
    log_file = os.getenv("LOG_FILE", "").strip()
    if log_file:
        try:
            handlers.append(RotatingFileHandler(log_file, maxBytes=2_000_000, backupCount=2, encoding="utf-8"))
        except OSError:
            pass
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(name)s: %(message)s", handlers=handlers)


_configure_logging()
logger = logging.getLogger(__name__)

# Create database tables
Base.metadata.create_all(bind=engine)
ensure_user_profile_columns(engine)

# Create application
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    debug=settings.DEBUG
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(chat.router, prefix="/api/v1", tags=["chat"])
app.include_router(profile.router, prefix="/api/v1", tags=["profile"])
app.include_router(assessment.router, prefix="/api/v1", tags=["assessment"])
app.include_router(journal.router, prefix="/api/v1", tags=["journal"])
app.include_router(conversations.router, prefix="/api/v1", tags=["conversations"])
app.include_router(tts.router, prefix="/api/v1", tags=["tts"])

if settings.DEBUG:
    logger.warning("DEBUG=True — لا تشغّل هذا الوضع في الإنتاج.")

# Root endpoints
@app.get("/")
async def root():
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "online ✅"
    }

@app.get("/health")
async def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="127.0.0.1", port=8000, reload=True)
