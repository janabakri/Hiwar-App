"""Provider adapter tests use local mock transports and never real keys."""

from io import BytesIO
import json
import wave

import httpx
import pytest

from app.ai.contracts.base import StrictContract
from app.ai.providers.azure_pronunciation import AzurePronunciationProvider, PronunciationProviderError
from app.ai.providers.factory import create_pronunciation_provider, create_text_provider
from app.ai.providers.gemini_text import GeminiTextProvider
from app.ai.providers.openai_text import OpenAITextProvider
from app.core.config import settings


class ExampleContract(StrictContract):
    answer: str


def _wav_bytes(*, seconds: float = 0.1, sample_rate: int = 16000, channels: int = 1) -> bytes:
    buffer = BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(channels)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(b"\x00\x00" * round(seconds * sample_rate) * channels)
    return buffer.getvalue()


def test_gemini_structured_provider_uses_header_and_validates_output(monkeypatch):
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "test-gemini-key")
    monkeypatch.setattr(settings, "GEMINI_MODEL", "gemini-test")
    monkeypatch.setattr(settings, "GEMINI_BASE_URL", "https://gemini.invalid/v1beta")

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["x-goog-api-key"] == "test-gemini-key"
        assert "test-gemini-key" not in str(request.url)
        body = json.loads(request.content)
        assert body["generationConfig"]["responseMimeType"] == "application/json"
        assert body["generationConfig"]["responseJsonSchema"]["additionalProperties"] is False
        return httpx.Response(
            200,
            json={
                "candidates": [{"content": {"parts": [{"text": '{"answer":"ok"}'}]}}],
                "usageMetadata": {"promptTokenCount": 12, "candidatesTokenCount": 4},
            },
        )

    provider = GeminiTextProvider(transport=httpx.MockTransport(handler))
    generated = provider.generate_structured(
        contract=ExampleContract,
        schema_name="example",
        system_prompt="system",
        user_prompt="user",
    )

    assert generated is not None
    assert generated.value.answer == "ok"
    assert generated.usage.provider == "google_gemini"
    assert generated.usage.input_tokens == 12
    assert generated.usage.output_tokens == 4


def test_gemini_provider_returns_none_without_key(monkeypatch):
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "")
    provider = GeminiTextProvider(
        transport=httpx.MockTransport(lambda _request: pytest.fail("network must not be called"))
    )

    assert provider.generate_structured(
        contract=ExampleContract,
        schema_name="example",
        system_prompt="system",
        user_prompt="user",
    ) is None


def test_gemini_text_generation_uses_the_same_central_adapter(monkeypatch):
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "test-gemini-key")

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["x-goog-api-key"] == "test-gemini-key"
        body = json.loads(request.content)
        assert body["generationConfig"]["responseMimeType"] == "application/json"
        return httpx.Response(
            200,
            json={
                "candidates": [{"content": {"parts": [{"text": '{"answer":"ok"}'}]}}],
                "usageMetadata": {"promptTokenCount": 3, "candidatesTokenCount": 2},
            },
        )

    generated = GeminiTextProvider(transport=httpx.MockTransport(handler)).generate_text(
        system_prompt="system",
        user_prompt="user",
        json_mode=True,
    )

    assert generated is not None
    assert generated.value == '{"answer":"ok"}'
    assert generated.usage.input_tokens == 3


def test_text_provider_selection_is_explicit_and_reversible(monkeypatch):
    monkeypatch.setattr(settings, "OPENAI_API_KEY", "openai-key")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "gemini-key")

    monkeypatch.setattr(settings, "AI_TEXT_PROVIDER", "gemini")
    assert isinstance(create_text_provider(), GeminiTextProvider)

    monkeypatch.setattr(settings, "AI_TEXT_PROVIDER", "openai")
    assert isinstance(create_text_provider(), OpenAITextProvider)

    monkeypatch.setattr(settings, "AI_TEXT_PROVIDER", "auto")
    assert isinstance(create_text_provider(), GeminiTextProvider)


def test_pronunciation_provider_can_be_disabled(monkeypatch):
    monkeypatch.setattr(settings, "PRONUNCIATION_PROVIDER", "disabled")
    assert create_pronunciation_provider() is None


@pytest.mark.asyncio
async def test_azure_pronunciation_parses_evidence_and_never_returns_audio(monkeypatch):
    monkeypatch.setattr(settings, "AZURE_SPEECH_KEY", "test-azure-key")
    monkeypatch.setattr(settings, "AZURE_SPEECH_REGION", "eastus")
    monkeypatch.setattr(settings, "AZURE_SPEECH_ENDPOINT", "")
    monkeypatch.setattr(settings, "AZURE_PRONUNCIATION_ENABLE_PROSODY", False)

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["ocp-apim-subscription-key"] == "test-azure-key"
        assert "test-azure-key" not in str(request.url)
        assert request.headers["content-type"].startswith("audio/wav")
        assert request.url.params["language"] == "en-US"
        return httpx.Response(
            200,
            json={
                "RecognitionStatus": "Success",
                "NBest": [
                    {
                        "Display": "Good morning.",
                        "AccuracyScore": 82.0,
                        "FluencyScore": 78.0,
                        "CompletenessScore": 100.0,
                        "PronScore": 84.0,
                        "Words": [
                            {
                                "Word": "Good",
                                "AccuracyScore": 60.0,
                                "ErrorType": "Mispronunciation",
                                "Offset": 10000,
                                "Duration": 20000,
                                "Phonemes": [{"Phoneme": "g", "AccuracyScore": 55.0}],
                            },
                            {"Word": "morning", "AccuracyScore": 95.0, "ErrorType": "None"},
                        ],
                    }
                ],
            },
        )

    provider = AzurePronunciationProvider(transport=httpx.MockTransport(handler))
    result, usage = await provider.assess(
        audio=_wav_bytes(),
        content_type="audio/wav",
        reference_text="Good morning.",
        locale="en-US",
    )

    assert result.reliable is True
    assert result.reference_match_score == 100
    assert result.pronunciation_score == 84
    assert result.words[0].phonemes[0].phoneme == "g"
    assert result.audio_retained is False
    assert "audio" not in result.model_dump()
    assert usage.provider == "azure_speech"


@pytest.mark.asyncio
async def test_azure_pronunciation_rejects_missing_scores(monkeypatch):
    monkeypatch.setattr(settings, "AZURE_SPEECH_KEY", "test-azure-key")
    monkeypatch.setattr(settings, "AZURE_SPEECH_REGION", "eastus")
    monkeypatch.setattr(settings, "AZURE_SPEECH_ENDPOINT", "")
    transport = httpx.MockTransport(
        lambda _request: httpx.Response(
            200,
            json={"RecognitionStatus": "Success", "NBest": [{"Display": "Good morning."}]},
        )
    )

    with pytest.raises(PronunciationProviderError) as error:
        await AzurePronunciationProvider(transport=transport).assess(
            audio=_wav_bytes(),
            content_type="audio/wav",
            reference_text="Good morning.",
        )

    assert error.value.code == "assessment_missing"


def test_azure_pronunciation_rejects_wrong_wav_format(monkeypatch):
    monkeypatch.setattr(settings, "PRONUNCIATION_MAX_AUDIO_BYTES", 2_097_152)

    with pytest.raises(PronunciationProviderError) as error:
        AzurePronunciationProvider.validate_audio(
            audio=_wav_bytes(sample_rate=44100, channels=2),
            content_type="audio/wav",
        )

    assert error.value.code == "unsupported_wav_format"
