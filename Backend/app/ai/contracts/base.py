"""Base contract configured for strict model and API output validation."""

from pydantic import BaseModel, ConfigDict


class StrictContract(BaseModel):
    model_config = ConfigDict(extra="forbid")
