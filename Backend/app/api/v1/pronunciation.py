"""Authenticated short-audio pronunciation assessment endpoint."""

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from ...ai.agents.tutor_orchestrator import TutorOrchestrator
from ...ai.contracts.pronunciation import PronunciationAssessmentResult
from ...ai.providers.azure_pronunciation import AzurePronunciationProvider, PronunciationProviderError
from ...ai.providers.factory import create_pronunciation_provider
from ...core.security import get_current_user
from ...core.config import settings
from ...core.database import get_db
from ...models.user import User


router = APIRouter()


def get_pronunciation_provider() -> AzurePronunciationProvider | None:
    return create_pronunciation_provider()


@router.post("/pronunciation/assess", response_model=PronunciationAssessmentResult)
async def assess_pronunciation(
    audio: UploadFile = File(...),
    reference_text: str = Form(..., min_length=1, max_length=1200),
    locale: str = Form(default="en-US", min_length=4, max_length=20),
    source_skill: str = Form(default="speaking", pattern="^(speaking|reading)$"),
    session_id: str | None = Form(default=None, max_length=48),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    provider: AzurePronunciationProvider | None = Depends(get_pronunciation_provider),
) -> PronunciationAssessmentResult:
    if provider is None or not provider.available:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "provider_not_configured",
                "message_ar": "تقييم النطق غير مفعّل بعد. أضف إعدادات Azure في أسرار بيئة التشغيل.",
            },
        )

    content_type = audio.content_type or ""
    try:
        audio_bytes = await audio.read(settings.PRONUNCIATION_MAX_AUDIO_BYTES + 1)
    finally:
        await audio.close()

    try:
        result, usage = await provider.assess(
            audio=audio_bytes,
            content_type=content_type,
            reference_text=reference_text,
            locale=locale,
        )
        TutorOrchestrator(db).record_pronunciation_assessment(
            user=user,
            source_skill=source_skill,
            session_public_id=session_id,
            result=result,
            usage=usage,
        )
        return result
    except PronunciationProviderError as exc:
        input_errors = {
            "empty_audio",
            "audio_too_large",
            "audio_too_long",
            "invalid_audio",
            "unsupported_audio_type",
            "unsupported_wav_format",
            "empty_reference",
            "reference_too_long",
            "unsupported_locale",
            "provider_rejected_audio",
            "speech_not_recognized",
        }
        unavailable_errors = {
            "provider_not_configured",
            "free_limit_reached",
            "invalid_credentials",
            "provider_unreachable",
        }
        status_code = 422 if exc.code in input_errors else 503 if exc.code in unavailable_errors else 502
        raise HTTPException(
            status_code=status_code,
            detail={"code": exc.code, "message_ar": exc.message_ar},
        ) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
