"""Provider selection kept outside tutor logic for safe, reversible routing."""

from ...core.config import settings
from .azure_pronunciation import AzurePronunciationProvider
from .base import StructuredTextProvider
from .gemini_text import GeminiTextProvider
from .openai_text import OpenAITextProvider


def create_text_provider() -> StructuredTextProvider:
    selected = settings.AI_TEXT_PROVIDER
    if selected == "gemini":
        return GeminiTextProvider()
    if selected == "openai":
        return OpenAITextProvider()
    if selected == "auto":
        if settings.GEMINI_API_KEY.strip():
            return GeminiTextProvider()
        if settings.OPENAI_API_KEY.strip():
            return OpenAITextProvider()
        # Returning an unavailable provider preserves the coaches' existing
        # deterministic fallback without introducing a second code path.
        return GeminiTextProvider()
    raise ValueError("AI_TEXT_PROVIDER must be one of: auto, openai, gemini")


def create_pronunciation_provider() -> AzurePronunciationProvider | None:
    selected = settings.PRONUNCIATION_PROVIDER
    if selected == "azure":
        return AzurePronunciationProvider()
    if selected in {"none", "disabled"}:
        return None
    raise ValueError("PRONUNCIATION_PROVIDER must be one of: azure, none, disabled")
