"""
Report generation endpoints for GigCredit backend.
"""

from fastapi import APIRouter, Depends

from ..auth import verify_api_key
from ..models.api import ApiResponse, ReportRequest

router = APIRouter(prefix="/report", tags=["report"])


@router.post("/generate", response_model=ApiResponse, dependencies=[Depends(verify_api_key)])
async def generate_report(payload: ReportRequest) -> ApiResponse:
    # TODO: call Gemini and return multilingual explanation JSON
    return ApiResponse(status="OK", data={"explanation": "", "suggestions": []}, error=None)

