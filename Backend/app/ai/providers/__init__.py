"""Replaceable AI provider adapters."""

from .base import ProviderUsage, StructuredGeneration, StructuredTextProvider, TextGeneration
from .azure_pronunciation import AzurePronunciationProvider, PronunciationProviderError
from .factory import create_pronunciation_provider, create_text_provider
from .gemini_text import GeminiTextProvider
from .openai_text import OpenAITextProvider

__all__ = [
    "GeminiTextProvider",
    "OpenAITextProvider",
    "AzurePronunciationProvider",
    "PronunciationProviderError",
    "ProviderUsage",
    "StructuredGeneration",
    "StructuredTextProvider",
    "TextGeneration",
    "create_pronunciation_provider",
    "create_text_provider",
]
