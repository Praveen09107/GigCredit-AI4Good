"""
Verification endpoints for GigCredit backend (simulation only).
"""

from fastapi import APIRouter, Depends

from ..auth import verify_api_key
from ..models.api import ApiResponse, VerifyRequest

router = APIRouter(prefix="/verify", tags=["verify"])


@router.post("/pan", response_model=ApiResponse, dependencies=[Depends(verify_api_key)])
async def verify_pan(payload: VerifyRequest) -> ApiResponse:
    # TODO: implement simulation lookup
    return ApiResponse(status="NOT_FOUND", data=None, error=None)

