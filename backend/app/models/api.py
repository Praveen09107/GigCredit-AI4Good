"""API-facing request and response models for GigCredit backend."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


ApiStatus = Literal["FOUND", "NOT_FOUND", "INVALID", "ERROR", "OK"]


class VerifyRequest(BaseModel):
    request_id: str | None = Field(default=None)
    identifier: str = Field(min_length=1)
    context: dict[str, Any] | None = None


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

