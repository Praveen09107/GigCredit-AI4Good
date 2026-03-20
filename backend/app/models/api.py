"""API-facing request and response models for GigCredit backend."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator, model_validator


ApiStatus = Literal["FOUND", "NOT_FOUND", "INVALID", "ERROR", "OK"]


class VerifyRequest(BaseModel):
    request_id: str | None = Field(default=None)
    user_id: str | None = Field(default=None)
    identifier: str | None = Field(default=None, min_length=1)
    data: dict[str, Any] | None = None
    timestamp: str | None = Field(default=None)
    signature: str | None = Field(default=None)
    context: dict[str, Any] | None = None

    @model_validator(mode="after")
    def _normalize_identifier(self) -> "VerifyRequest":
        if self.identifier and self.identifier.strip():
            self.identifier = self.identifier.strip()
            return self

        if self.data and isinstance(self.data, dict):
            for key in ("identifier", "id", "value"):
                candidate = self.data.get(key)
                if isinstance(candidate, str) and candidate.strip():
                    self.identifier = candidate.strip()
                    break

            if self.context is None:
                nested_context = self.data.get("context")
                if isinstance(nested_context, dict):
                    self.context = nested_context

        if self.identifier is None or not self.identifier.strip():
            raise ValueError("identifier is required, either as top-level field or data.identifier")

        return self


class ApiResponse(BaseModel):
    status: ApiStatus
    data: dict[str, Any] | None = None
    error: str | None = None
    trace_id: str | None = None


class FactorItem(BaseModel):
    key: str
    label: str | None = None
    value: float | None = None
    direction: Literal["positive", "negative"] | None = None


class ReportRequest(BaseModel):
    request_id: str | None = Field(default=None)
    language: str = Field(default="en", min_length=2, max_length=8)
    score: float = Field(ge=300, le=900)
    pillars: dict[str, float]
    shap_factors: list[FactorItem] = Field(default_factory=list)

    @field_validator("language", mode="before")
    @classmethod
    def _normalize_language(cls, value: Any) -> str:
        raw = str(value or "en").strip().lower()
        if not raw:
            return "en"

        base = raw.split("-")[0].split("_")[0]
        if base in {"en", "hi", "ta"}:
            return base
        return "en"

    @field_validator("pillars")
    @classmethod
    def _validate_pillars(cls, value: dict[str, float]) -> dict[str, float]:
        expected = {"p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8"}
        received = set(value.keys())
        if received != expected:
            raise ValueError("pillars must contain exactly p1..p8")

        normalized: dict[str, float] = {}
        for key, pillar in value.items():
            score = float(pillar)
            if score < 0.0 or score > 1.0:
                raise ValueError(f"pillar {key} must be between 0 and 1")
            normalized[key] = score
        return normalized

