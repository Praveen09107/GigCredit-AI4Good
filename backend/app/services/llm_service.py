"""Gemini LLM client wrapper for GigCredit report generation."""

from __future__ import annotations

import json
import importlib
from urllib import request as urlrequest
from urllib import error as urlerror

from ..config import settings
from ..models.api import ApiResponse, ReportRequest


def _default_suggestions(language: str) -> list[str]:
    if language == "hi":
        return [
            "नियमित आय जमा बनाए रखें।",
            "जहां संभव हो EMI बोझ कम करें।",
            "यूटिलिटी और भुगतान समय पर रखें।",
        ]
    if language == "ta":
        return [
            "சீரான வருமான வரவுகளை தொடர்ந்து வைத்திருக்கவும்.",
            "சாத்தியமான இடங்களில் EMI சுமையை குறைக்கவும்.",
            "யூட்டிலிட்டி மற்றும் கட்டணங்களை நேரத்தில் செலுத்தவும்.",
        ]
    return [
        "Maintain consistent income deposits.",
        "Reduce EMI burden where possible.",
        "Keep utility and payment cycles on time.",
    ]


def _fallback_report(payload: ReportRequest) -> dict[str, object]:
    score = payload.score
    if score <= 450:
        risk = "high"
    elif score <= 650:
        risk = "medium"
    else:
        risk = "low"

    if payload.language == "hi":
        explanation = (
            f"आपका GigCredit स्कोर {int(score)} है और जोखिम स्तर {risk} है। "
            "यह अनुमान सत्यापित प्रोफ़ाइल और वित्तीय व्यवहार संकेतों पर आधारित है।"
        )
    elif payload.language == "ta":
        explanation = (
            f"உங்கள் GigCredit மதிப்பெண் {int(score)} மற்றும் அபாய நிலை {risk} ஆகும். "
            "இந்த மதிப்பீடு சரிபார்க்கப்பட்ட சுயவிவர மற்றும் நிதி நடத்தை சிக்னல்களை அடிப்படையாகக் கொண்டது."
        )
    else:
        explanation = (
            f"Your GigCredit score is {int(score)} with {risk} risk. "
            "This estimate is based on verified profile and financial behavior signals."
        )
    suggestions = _default_suggestions(payload.language)
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


def _looks_like_groq_key(key: str) -> bool:
    return key.startswith("gsk_")


def _normalize_report_data(payload: ReportRequest, report: dict[str, object]) -> dict[str, object]:
    explanation = report.get("explanation")
    if not isinstance(explanation, str) or not explanation.strip():
        explanation = _fallback_report(payload)["explanation"]

    raw_suggestions = report.get("suggestions")
    if isinstance(raw_suggestions, list):
        suggestions = [item for item in raw_suggestions if isinstance(item, str) and item.strip()]
    else:
        suggestions = []

    if len(suggestions) < 3:
        suggestions = _default_suggestions(payload.language)
    elif len(suggestions) > 5:
        suggestions = suggestions[:5]

    return {
        "language": payload.language,
        "score": payload.score,
        "pillars": dict(payload.pillars),
        "explanation": explanation,
        "suggestions": suggestions,
    }


def _immutable_report_shell(payload: ReportRequest) -> dict[str, object]:
    return {
        "language": payload.language,
        "score": payload.score,
        "pillars": dict(payload.pillars),
        "explanation": "",
        "suggestions": [],
    }


def _generate_with_groq(payload: ReportRequest) -> dict[str, object]:
    body = {
        "model": "llama-3.1-8b-instant",
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
        "messages": [
            {
                "role": "system",
                "content": (
                    "Return strict JSON only with keys explanation (string) and "
                    "suggestions (array of 3 to 5 strings). Do not alter score or pillars."
                ),
            },
            {
                "role": "user",
                "content": _build_prompt(payload),
            },
        ],
    }
    raw = json.dumps(body).encode("utf-8")
    req = urlrequest.Request(
        url="https://api.groq.com/openai/v1/chat/completions",
        data=raw,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {settings.gemini_api_key}",
        },
    )

    with urlrequest.urlopen(req, timeout=15) as response:
        payload_json = json.loads(response.read().decode("utf-8"))

    content = (
        payload_json.get("choices", [{}])[0]
        .get("message", {})
        .get("content", "{}")
    )
    parsed = json.loads(content)
    explanation = parsed.get("explanation")
    suggestions = parsed.get("suggestions")
    if not isinstance(explanation, str) or not isinstance(suggestions, list):
        raise ValueError("Invalid report structure from Groq model")
    return {"explanation": explanation, "suggestions": suggestions[:5]}


def generate_credit_report(payload: ReportRequest, trace_id: str | None) -> ApiResponse:
    if not settings.gemini_api_key:
        if settings.require_production_readiness:
            return ApiResponse(
                status="ERROR",
                data=_immutable_report_shell(payload),
                error="GEMINI_API_KEY missing; strict production mode disallows fallback templates",
                trace_id=trace_id,
            )
        return ApiResponse(
            status="OK",
            data=_fallback_report(payload),
            error="GEMINI_API_KEY missing; fallback template used",
            trace_id=trace_id,
        )

    try:
        if _looks_like_groq_key(settings.gemini_api_key):
            return ApiResponse(
                status="OK",
                data=_normalize_report_data(payload, _generate_with_groq(payload)),
                error=None,
                trace_id=trace_id,
            )

        genai = importlib.import_module("google.generativeai")
        genai.configure(api_key=settings.gemini_api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(_build_prompt(payload))
        raw_text = response.text or "{}"
        parsed = json.loads(raw_text)

        return ApiResponse(
            status="OK",
            data=_normalize_report_data(payload, parsed),
            error=None,
            trace_id=trace_id,
        )
    except (urlerror.URLError, urlerror.HTTPError, Exception):
        if settings.require_production_readiness:
            return ApiResponse(
                status="ERROR",
                data=_immutable_report_shell(payload),
                error="LLM generation failed; strict production mode disallows fallback templates",
                trace_id=trace_id,
            )
        return ApiResponse(
            status="ERROR",
            data=_fallback_report(payload),
            error="LLM generation failed; fallback template used",
            trace_id=trace_id,
        )

