"""OpenAI structured-output adapter for tutor decisions.

The provider is intentionally isolated from teaching logic. Agents can fall
back to deterministic behavior when no key is configured, and a different
provider can be introduced without changing API routes or memory rules.
"""

import json
import re
from dataclasses import dataclass
from time import monotonic
from typing import Generic, TypeVar

from openai import OpenAI
from pydantic import BaseModel, ValidationError

from ...core.config import settings


ContractT = TypeVar("ContractT", bound=BaseModel)


@dataclass(frozen=True)
class ProviderUsage:
    provider: str
    model: str
    input_tokens: int
    output_tokens: int
    duration_ms: int


@dataclass(frozen=True)
class StructuredGeneration(Generic[ContractT]):
    value: ContractT
    usage: ProviderUsage


class OpenAITextProvider:
    def __init__(self) -> None:
        self.model = settings.AI_TUTOR_MODEL

    @property
    def available(self) -> bool:
        return bool(settings.OPENAI_API_KEY.strip())

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

        client = OpenAI(
            api_key=settings.OPENAI_API_KEY,
            base_url=settings.OPENAI_BASE_URL,
            timeout=settings.AI_TUTOR_TIMEOUT_SECONDS,
        )
        started = monotonic()
        schema = contract.model_json_schema()
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        try:
            response = client.chat.completions.create(
                model=self.model,
                messages=messages,
                response_format={
                    "type": "json_schema",
                    "json_schema": {
                        "name": schema_name,
                        "strict": True,
                        "schema": schema,
                    },
                },
                temperature=temperature,
                max_tokens=settings.AI_TUTOR_MAX_TOKENS,
            )
        except (TypeError, ValueError):
            # Compatibility path for older OpenAI-compatible gateways. The
            # returned payload is still validated by Pydantic before use.
            response = client.chat.completions.create(
                model=self.model,
                messages=[
                    messages[0],
                    {
                        "role": "user",
                        "content": f"{user_prompt}\nReturn JSON matching this schema exactly:\n{json.dumps(schema)}",
                    },
                ],
                response_format={"type": "json_object"},
                temperature=temperature,
                max_tokens=settings.AI_TUTOR_MAX_TOKENS,
            )

        content = response.choices[0].message.content or ""
        content = re.sub(r"^```(?:json)?\s*|\s*```$", "", content.strip(), flags=re.IGNORECASE)
        try:
            value = contract.model_validate_json(content)
        except ValidationError as exc:
            raise ValueError(f"AI response failed {schema_name} validation") from exc

        raw_usage = getattr(response, "usage", None)
        usage = ProviderUsage(
            provider="openai",
            model=self.model,
            input_tokens=int(getattr(raw_usage, "prompt_tokens", 0) or 0),
            output_tokens=int(getattr(raw_usage, "completion_tokens", 0) or 0),
            duration_ms=max(0, round((monotonic() - started) * 1000)),
        )
        return StructuredGeneration(value=value, usage=usage)
