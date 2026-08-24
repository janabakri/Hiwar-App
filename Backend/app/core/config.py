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
    DEBUG: bool = os.getenv("DEBUG", "False").lower() in {"1", "true", "yes", "on"}
    APP_ENV: str = os.getenv("APP_ENV", "development").lower()

    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./app.db")

    # AI Providers
    AI_TEXT_PROVIDER: str = os.getenv("AI_TEXT_PROVIDER", "openai").strip().lower()
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    OPENAI_BASE_URL: str = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
    OPENAI_MODEL: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    # Azure Speech
    PRONUNCIATION_PROVIDER: str = os.getenv("PRONUNCIATION_PROVIDER", "none").strip().lower()
    AZURE_SPEECH_KEY: str = os.getenv("AZURE_SPEECH_KEY", "")
    AZURE_SPEECH_REGION: str = os.getenv("AZURE_SPEECH_REGION", "")
    AZURE_SPEECH_LANGUAGE: str = os.getenv("AZURE_SPEECH_LANGUAGE", "en-US")

    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
    ALLOW_MANUAL_AUTH: bool = os.getenv("ALLOW_MANUAL_AUTH", "False").lower() in {"1", "true", "yes", "on"}
    CORS_ORIGINS: list[str] = [item.strip() for item in os.getenv(
        "CORS_ORIGINS", "http://localhost:3000,http://localhost:5173"
    ).split(",") if item.strip()]
    GOOGLE_CLIENT_ID: str = os.getenv("GOOGLE_CLIENT_ID", "")
    APPLE_CLIENT_ID: str = os.getenv("APPLE_CLIENT_ID", "")

    # Email verification
    SMTP_HOST: str = os.getenv("SMTP_HOST", "")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USERNAME: str = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM: str = os.getenv("SMTP_FROM", "")
    SMTP_FROM_NAME: str = os.getenv("SMTP_FROM_NAME", "حوار App")

    def validate(self) -> None:
        if self.APP_ENV in {"production", "prod"}:
            if len(self.SECRET_KEY) < 32:
                raise RuntimeError("SECRET_KEY must contain at least 32 characters in production")
            if "*" in self.CORS_ORIGINS:
                raise RuntimeError("Wildcard CORS is forbidden in production")


settings = Settings()
settings.validate()
