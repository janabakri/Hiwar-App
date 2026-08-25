"""Shared contracts for replaceable AI provider adapters."""

from dataclasses import dataclass
from typing import Generic, Protocol, TypeVar

from pydantic import BaseModel


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


@dataclass(frozen=True)
class TextGeneration:
    value: str
    usage: ProviderUsage


class StructuredTextProvider(Protocol):
    """Minimal interface consumed by the speaking and reading coaches."""

    @property
    def available(self) -> bool: ...

    def generate_structured(
        self,
        *,
        contract: type[ContractT],
        schema_name: str,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.2,
    ) -> StructuredGeneration[ContractT] | None: ...

    def generate_text(
        self,
        *,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.2,
        json_mode: bool = False,
    ) -> TextGeneration | None: ...
