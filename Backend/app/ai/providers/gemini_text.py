"""Gemini structured-output adapter used by the temporary free-tier setup.

The key is sent in a request header rather than the URL so it cannot leak via
normal URL logging. Provider failures are allowed to bubble to the coaches,
which already fall back to deterministic teaching behavior.
"""

import json
import re
from time import monotonic
from typing import Any, TypeVar

import httpx
from pydantic import BaseModel, ValidationError

from ...core.config import settings
from .base import ProviderUsage, StructuredGeneration, TextGeneration


ContractT = TypeVar("ContractT", bound=BaseModel)


class GeminiTextProvider:
    def __init__(self, *, transport: httpx.BaseTransport | None = None) -> None:
        self.model = settings.GEMINI_MODEL
        self._transport = transport

    @property
    def available(self) -> bool:
        return bool(settings.GEMINI_API_KEY.strip())

    def generate_structured(
        self,
        *,
        contract: type[ContractT],
        schema_name: str,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.2,
    ) -> StructuredGeneration[ContractT] | None:
        if not self.available:
            return None

        started = monotonic()
        schema = contract.model_json_schema()
        payload: dict[str, Any] = {
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": user_prompt}],
                }
            ],
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": settings.AI_TUTOR_MAX_TOKENS,
                "responseMimeType": "application/json",
                "responseJsonSchema": schema,
            },
        }
        url = f"{settings.GEMINI_BASE_URL}/models/{self.model}:generateContent"
        try:
            with httpx.Client(
                timeout=settings.AI_TUTOR_TIMEOUT_SECONDS,
                transport=self._transport,
            ) as client:
                response = client.post(
                    url,
                    headers={
                        "x-goog-api-key": settings.GEMINI_API_KEY,
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
        except httpx.HTTPError as exc:
            raise RuntimeError("Gemini request failed") from exc

        if response.status_code >= 400:
            # Do not include the response body: provider errors may echo parts
            # of the learner prompt and should not be copied into application
            # logs or public API responses.
            raise RuntimeError(f"Gemini request failed with status {response.status_code}")

        try:
            raw = response.json()
            parts = raw["candidates"][0]["content"]["parts"]
            content = "".join(str(part.get("text", "")) for part in parts)
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise ValueError(f"Gemini returned no valid {schema_name} content") from exc

        content = re.sub(r"^```(?:json)?\s*|\s*```$", "", content.strip(), flags=re.IGNORECASE)
        try:
            value = contract.model_validate_json(content)
        except ValidationError as exc:
            raise ValueError(f"AI response failed {schema_name} validation") from exc

        raw_usage = raw.get("usageMetadata") or {}
        usage = ProviderUsage(
            provider="google_gemini",
            model=self.model,
            input_tokens=int(raw_usage.get("promptTokenCount") or 0),
            output_tokens=int(raw_usage.get("candidatesTokenCount") or 0),
            duration_ms=max(0, round((monotonic() - started) * 1000)),
        )
        return StructuredGeneration(value=value, usage=usage)

    def generate_text(
        self,
        *,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.2,
        json_mode: bool = False,
    ) -> TextGeneration | None:
        if not self.available:
            return None

        started = monotonic()
        generation_config: dict[str, Any] = {
            "temperature": temperature,
            "maxOutputTokens": settings.AI_TUTOR_MAX_TOKENS,
        }
        if json_mode:
            generation_config["responseMimeType"] = "application/json"
        payload = {
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
            "generationConfig": generation_config,
        }
        url = f"{settings.GEMINI_BASE_URL}/models/{self.model}:generateContent"
        try:
            with httpx.Client(timeout=settings.AI_TUTOR_TIMEOUT_SECONDS, transport=self._transport) as client:
                response = client.post(
                    url,
                    headers={"x-goog-api-key": settings.GEMINI_API_KEY, "Content-Type": "application/json"},
                    json=payload,
                )
        except httpx.HTTPError as exc:
            raise RuntimeError("Gemini request failed") from exc
        if response.status_code >= 400:
            raise RuntimeError(f"Gemini request failed with status {response.status_code}")
        try:
            raw = response.json()
            parts = raw["candidates"][0]["content"]["parts"]
            content = "".join(str(part.get("text", "")) for part in parts).strip()
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise ValueError("Gemini returned no valid text content") from exc
        if not content:
            raise ValueError("Gemini returned empty text content")
        raw_usage = raw.get("usageMetadata") or {}
        return TextGeneration(
            value=content,
            usage=ProviderUsage(
                provider="google_gemini",
                model=self.model,
                input_tokens=int(raw_usage.get("promptTokenCount") or 0),
                output_tokens=int(raw_usage.get("candidatesTokenCount") or 0),
                duration_ms=max(0, round((monotonic() - started) * 1000)),
            ),
        )
