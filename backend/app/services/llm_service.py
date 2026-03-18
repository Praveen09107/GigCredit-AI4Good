"""
Gemini LLM client wrapper for GigCredit report generation.
"""

from ..models.api import ReportRequest, ApiResponse


async def generate_credit_report(payload: ReportRequest) -> ApiResponse:
    # TODO: implement Gemini API call based on MASTER PROMPT spec.
    return ApiResponse(status="OK", data={"explanation": "", "suggestions": []}, error=None)

