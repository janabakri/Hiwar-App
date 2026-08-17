"""
Application configuration.
Loads environment variables and stores settings.
"""

import os
from pathlib import Path


def _load_environment() -> None:
    """Load environment variables from the backend .env file when present."""
    base_dir = Path(__file__).resolve().parents[2]
    candidates = [
        Path(os.getenv("ENV_FILE", "")) if os.getenv("ENV_FILE") else None,
        base_dir / ".env",
        base_dir.parent / ".env",
        Path.cwd() / ".env",
    ]

    for candidate in candidates:
        if not candidate:
            continue

        try:
            if candidate.exists() and candidate.is_file():
                content = candidate.read_text(encoding="utf-8", errors="ignore")
                for line in content.splitlines():
                    stripped = line.strip()
                    if not stripped or stripped.startswith("#"):
                        continue
                    if "=" not in stripped:
                        continue
                    key, value = stripped.split("=", 1)
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    os.environ.setdefault(key, value)
                break
        except OSError:
            continue


_load_environment()


class Settings:
    # App
    APP_NAME: str = os.getenv("APP_NAME", "Hiwar App")
    APP_VERSION: str = os.getenv("APP_VERSION", "1.0.0")
    DEBUG: bool = os.getenv("DEBUG", "True").lower() in {"1", "true", "yes", "on"}

    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./app.db")

    # AI Provider
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY") or os.getenv("OPENAI_API_KEY", "")
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    OPENAI_BASE_URL: str = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
    OPENAI_MODEL: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-here")
    GOOGLE_CLIENT_ID: str = os.getenv("GOOGLE_CLIENT_ID", "")

    # Email verification
    SMTP_HOST: str = os.getenv("SMTP_HOST", "")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USERNAME: str = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM: str = os.getenv("SMTP_FROM", "")


settings = Settings()
