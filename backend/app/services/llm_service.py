"""Gemini LLM client wrapper for GigCredit report generation."""

from __future__ import annotations

import json
import importlib

from ..config import settings
from ..models.api import ApiResponse, ReportRequest


def _fallback_report(payload: ReportRequest) -> dict[str, object]:
    score = payload.score
    if score <= 450:
        risk = "high"
    elif score <= 650:
        risk = "medium"
    else:
        risk = "low"

    explanation = (
        f"Your GigCredit score is {int(score)} with {risk} risk. "
        "This estimate is based on verified profile and financial behavior signals."
    )
    suggestions = [
        "Maintain consistent income deposits.",
        "Reduce EMI burden where possible.",
        "Keep utility and payment cycles on time.",
    ]
    return {"explanation": explanation, "suggestions": suggestions}


def _build_prompt(payload: ReportRequest) -> str:
    return (
        "You are a financial explanation assistant. Return strict JSON only with keys "
        "explanation (string) and suggestions (array of 3 to 5 strings). "
        "Do not alter the score or pillar values. "
        f"Language: {payload.language}. "
        f"Score: {payload.score}. "
        f"Pillars: {json.dumps(payload.pillars)}. "
        f"Factors: {json.dumps([item.model_dump() for item in payload.shap_factors])}."
    )


def generate_credit_report(payload: ReportRequest, trace_id: str | None) -> ApiResponse:
    if not settings.gemini_api_key:
        return ApiResponse(
            status="OK",
            data=_fallback_report(payload),
            error="GEMINI_API_KEY missing; fallback template used",
            trace_id=trace_id,
        )

    try:
        genai = importlib.import_module("google.generativeai")
        genai.configure(api_key=settings.gemini_api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(_build_prompt(payload))
        raw_text = response.text or "{}"
        parsed = json.loads(raw_text)

        explanation = parsed.get("explanation")
        suggestions = parsed.get("suggestions")
        if not isinstance(explanation, str) or not isinstance(suggestions, list):
            raise ValueError("Invalid report structure from model")

        return ApiResponse(
            status="OK",
            data={"explanation": explanation, "suggestions": suggestions[:5]},
            error=None,
            trace_id=trace_id,
        )
    except Exception:
        return ApiResponse(
            status="ERROR",
            data=_fallback_report(payload),
            error="LLM generation failed; fallback template used",
            trace_id=trace_id,
        )

