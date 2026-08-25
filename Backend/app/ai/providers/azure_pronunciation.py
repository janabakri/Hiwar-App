"""Azure Speech pronunciation adapter for short, non-retained audio clips."""

import base64
from difflib import SequenceMatcher
from io import BytesIO
import json
import re
from time import monotonic
from typing import Any
import wave

import httpx

from ...core.config import settings
from ..contracts.pronunciation import (
    PronunciationAssessmentResult,
    PronunciationPhonemeScore,
    PronunciationWordScore,
)
from .base import ProviderUsage


class PronunciationProviderError(RuntimeError):
    """Safe provider failure that API routes can expose without leaking data."""

    def __init__(self, code: str, message_ar: str):
        super().__init__(code)
        self.code = code
        self.message_ar = message_ar


class AzurePronunciationProvider:
    _WAV_TYPES = {"audio/wav", "audio/x-wav", "audio/wave"}
    _OGG_TYPES = {"audio/ogg", "application/ogg"}

    def __init__(self, *, transport: httpx.AsyncBaseTransport | None = None) -> None:
        self._transport = transport

    @property
    def available(self) -> bool:
        has_endpoint = bool(settings.AZURE_SPEECH_ENDPOINT or settings.AZURE_SPEECH_REGION)
        return bool(settings.AZURE_SPEECH_KEY.strip() and has_endpoint)

    async def assess(
        self,
        *,
        audio: bytes,
        content_type: str,
        reference_text: str,
        locale: str = "en-US",
    ) -> tuple[PronunciationAssessmentResult, ProviderUsage]:
        if not self.available:
            raise PronunciationProviderError(
                "provider_not_configured",
                "تقييم النطق غير مفعّل بعد. أضف مفتاح Azure والمنطقة في أسرار بيئة التشغيل.",
            )

        normalized_reference = " ".join(reference_text.split())
        if not normalized_reference:
            raise PronunciationProviderError("empty_reference", "النص المرجعي مطلوب لتقييم النطق.")
        if len(normalized_reference) > 1200:
            raise PronunciationProviderError("reference_too_long", "النص المرجعي أطول من الحد المسموح.")
        if not re.fullmatch(r"en-[A-Za-z]{2}", locale):
            raise PronunciationProviderError("unsupported_locale", "نسخة التقييم الحالية تدعم لهجات الإنجليزية فقط.")

        azure_content_type = self.validate_audio(audio=audio, content_type=content_type)
        parameters: dict[str, Any] = {
            "ReferenceText": normalized_reference,
            "GradingSystem": "HundredMark",
            "Granularity": "Phoneme",
            "Dimension": "Comprehensive",
            "EnableMiscue": True,
        }
        if settings.AZURE_PRONUNCIATION_ENABLE_PROSODY and locale == "en-US":
            parameters["EnableProsodyAssessment"] = "True"
        encoded_parameters = base64.b64encode(
            json.dumps(parameters, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        ).decode("ascii")

        started = monotonic()
        try:
            async with httpx.AsyncClient(
                timeout=settings.AZURE_SPEECH_TIMEOUT_SECONDS,
                transport=self._transport,
            ) as client:
                response = await client.post(
                    self._endpoint(),
                    params={"language": locale, "format": "detailed", "profanity": "masked"},
                    headers={
                        "Ocp-Apim-Subscription-Key": settings.AZURE_SPEECH_KEY,
                        "Pronunciation-Assessment": encoded_parameters,
                        "Content-Type": azure_content_type,
                        "Accept": "application/json",
                    },
                    content=audio,
                )
        except httpx.HTTPError as exc:
            raise PronunciationProviderError(
                "provider_unreachable",
                "تعذر الوصول إلى خدمة تقييم النطق. حاول مرة أخرى لاحقًا.",
            ) from exc

        if response.status_code == 429:
            raise PronunciationProviderError(
                "free_limit_reached",
                "تم الوصول إلى الحد المؤقت لخدمة تقييم النطق. المحادثة ستستمر دون درجة نطق.",
            )
        if response.status_code in {401, 403}:
            raise PronunciationProviderError(
                "invalid_credentials",
                "إعدادات Azure غير صحيحة أو لا تسمح بتقييم النطق.",
            )
        if response.status_code >= 400:
            raise PronunciationProviderError(
                "provider_rejected_audio",
                "تعذر تحليل الملف الصوتي. استخدم WAV بصيغة PCM، أحادي القناة، وبتردد 16kHz.",
            )

        try:
            payload = response.json()
        except ValueError as exc:
            raise PronunciationProviderError(
                "invalid_provider_response",
                "وصل رد غير صالح من خدمة تقييم النطق.",
            ) from exc
        if not isinstance(payload, dict):
            raise PronunciationProviderError(
                "invalid_provider_response",
                "وصل رد غير صالح من خدمة تقييم النطق.",
            )

        result = self._parse_response(
            payload=payload,
            reference_text=normalized_reference,
            locale=locale,
        )
        usage = ProviderUsage(
            provider="azure_speech",
            model="pronunciation-assessment",
            input_tokens=0,
            output_tokens=0,
            duration_ms=max(0, round((monotonic() - started) * 1000)),
        )
        return result, usage

    @classmethod
    def validate_audio(cls, *, audio: bytes, content_type: str) -> str:
        if not audio:
            raise PronunciationProviderError("empty_audio", "الملف الصوتي فارغ.")
        if len(audio) > settings.PRONUNCIATION_MAX_AUDIO_BYTES:
            raise PronunciationProviderError("audio_too_large", "الملف الصوتي أكبر من الحد المسموح.")

        media_type = content_type.split(";", 1)[0].strip().lower()
        if media_type in cls._WAV_TYPES:
            cls._validate_wav(audio)
            return "audio/wav; codecs=audio/pcm; samplerate=16000"
        if media_type in cls._OGG_TYPES:
            if not audio.startswith(b"OggS"):
                raise PronunciationProviderError("invalid_audio", "ملف OGG غير صالح.")
            return "audio/ogg; codecs=opus"
        raise PronunciationProviderError(
            "unsupported_audio_type",
            "صيغة الصوت غير مدعومة. استخدم WAV PCM 16kHz أو OGG Opus.",
        )

    @staticmethod
    def _validate_wav(audio: bytes) -> None:
        try:
            with wave.open(BytesIO(audio), "rb") as wav_file:
                channels = wav_file.getnchannels()
                sample_rate = wav_file.getframerate()
                sample_width = wav_file.getsampwidth()
                compression = wav_file.getcomptype()
                frames = wav_file.getnframes()
        except (EOFError, wave.Error) as exc:
            raise PronunciationProviderError("invalid_audio", "ملف WAV غير صالح.") from exc

        if channels != 1 or sample_rate != 16000 or sample_width != 2 or compression != "NONE":
            raise PronunciationProviderError(
                "unsupported_wav_format",
                "يجب أن يكون WAV بصيغة PCM 16-bit، أحادي القناة، وبتردد 16kHz.",
            )
        if frames / sample_rate > 30.0:
            raise PronunciationProviderError("audio_too_long", "يجب ألا يتجاوز تسجيل التقييم 30 ثانية.")

    @staticmethod
    def _score(container: dict[str, Any], key: str) -> float | None:
        value = container.get(key)
        if value is None and isinstance(container.get("PronunciationAssessment"), dict):
            value = container["PronunciationAssessment"].get(key)
        if value is None:
            return None
        try:
            return max(0.0, min(100.0, float(value)))
        except (TypeError, ValueError):
            return None

    @classmethod
    def _parse_response(
        cls,
        *,
        payload: dict[str, Any],
        reference_text: str,
        locale: str,
    ) -> PronunciationAssessmentResult:
        status = payload.get("RecognitionStatus")
        if status != "Success":
            raise PronunciationProviderError(
                "speech_not_recognized",
                "لم يتم التعرف على كلام واضح. اقترب من الميكروفون وحاول مرة أخرى.",
            )
        candidates = payload.get("NBest") or []
        if not candidates or not isinstance(candidates[0], dict):
            raise PronunciationProviderError(
                "assessment_missing",
                "لم تُرجع الخدمة تقييم نطق صالحًا، لذلك لن نعرض درجة.",
            )
        best = candidates[0]
        accuracy = cls._score(best, "AccuracyScore")
        if accuracy is None:
            raise PronunciationProviderError(
                "assessment_missing",
                "لم تُرجع الخدمة دليلًا صوتيًا كافيًا، لذلك لن نعرض درجة نطق.",
            )

        recognized = str(best.get("Display") or best.get("Lexical") or payload.get("DisplayText") or "").strip()
        if not recognized:
            raise PronunciationProviderError(
                "speech_not_recognized",
                "لم يتم التعرف على كلام واضح. حاول مرة أخرى.",
            )
        reference_match = cls._text_similarity(reference_text, recognized)
        reliable = reference_match >= 60
        warning = None
        if not reliable:
            warning = "الكلام المتعرف عليه لا يطابق النص المرجعي بما يكفي؛ لا تُستخدم هذه الدرجة لتحديث تقدمك."

        words: list[PronunciationWordScore] = []
        for raw_word in (best.get("Words") or [])[:160]:
            if not isinstance(raw_word, dict) or not str(raw_word.get("Word") or "").strip():
                continue
            nested = raw_word.get("PronunciationAssessment")
            nested = nested if isinstance(nested, dict) else {}
            raw_phonemes = raw_word.get("Phonemes") or nested.get("Phonemes") or []
            phonemes = []
            for raw_phoneme in raw_phonemes[:40]:
                if not isinstance(raw_phoneme, dict):
                    continue
                name = str(raw_phoneme.get("Phoneme") or "").strip()
                if name:
                    phonemes.append(
                        PronunciationPhonemeScore(
                            phoneme=name,
                            accuracy_score=cls._score(raw_phoneme, "AccuracyScore"),
                        )
                    )
            offset = cls._ticks_to_ms(raw_word.get("Offset"))
            duration = cls._ticks_to_ms(raw_word.get("Duration"))
            words.append(
                PronunciationWordScore(
                    word=str(raw_word["Word"]).strip(),
                    accuracy_score=cls._score(raw_word, "AccuracyScore"),
                    error_type=str(raw_word.get("ErrorType") or nested.get("ErrorType") or "None"),
                    offset_ms=offset,
                    duration_ms=duration,
                    phonemes=phonemes,
                )
            )

        return PronunciationAssessmentResult(
            locale=locale,
            reference_text=reference_text,
            recognized_text=recognized,
            pronunciation_score=cls._score(best, "PronScore"),
            accuracy_score=accuracy,
            fluency_score=cls._score(best, "FluencyScore"),
            completeness_score=cls._score(best, "CompletenessScore"),
            prosody_score=cls._score(best, "ProsodyScore"),
            reference_match_score=reference_match,
            reliable=reliable,
            warning_ar=warning,
            words=words,
            audio_retained=False,
        )

    @staticmethod
    def _ticks_to_ms(value: Any) -> int | None:
        try:
            return max(0, round(float(value) / 10_000))
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _text_similarity(first: str, second: str) -> int:
        normalize = lambda value: " ".join(re.findall(r"[a-z0-9']+", value.lower()))
        return round(SequenceMatcher(None, normalize(first), normalize(second)).ratio() * 100)

    @staticmethod
    def _endpoint() -> str:
        if settings.AZURE_SPEECH_ENDPOINT:
            endpoint = settings.AZURE_SPEECH_ENDPOINT
            if "/speech/recognition/" in endpoint or "/stt/speech/" in endpoint:
                return endpoint
            return f"{endpoint}/stt/speech/recognition/conversation/cognitiveservices/v1"
        return (
            f"https://{settings.AZURE_SPEECH_REGION}.stt.speech.microsoft.com"
            "/speech/recognition/conversation/cognitiveservices/v1"
        )
