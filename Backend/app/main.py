"""
Hiwar App - Main Server
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .core.config import settings
from .core.database import engine, Base
from .core.migrations import ensure_user_profile_columns
from .api.v1 import assessment, chat, learning_plan, profile, pronunciation, reading, speaking
from . import models  # noqa: F401  # register every table before create_all

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
app.include_router(speaking.router, prefix="/api/v1", tags=["speaking-agent"])
app.include_router(reading.router, prefix="/api/v1", tags=["reading-agent"])
app.include_router(pronunciation.router, prefix="/api/v1", tags=["pronunciation"])
app.include_router(learning_plan.router, prefix="/api/v1", tags=["learning-plan"])

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
