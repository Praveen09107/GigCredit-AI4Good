"""
API-facing request and response models for GigCredit backend.
"""

from typing import Any

from pydantic import BaseModel


class VerifyRequest(BaseModel):
    identifier: str
    extra: dict[str, Any] | None = None


class ApiResponse(BaseModel):
    status: str
    data: dict[str, Any] | None = None
    error: str | None = None


class ReportRequest(BaseModel):
    language: str
    score: float
    pillars: dict[str, float]
    shap_factors: list[dict[str, Any]]

