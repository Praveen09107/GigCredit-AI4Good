"""Report generation endpoints for GigCredit backend."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, Header

from ..auth import verify_api_key
from ..database import get_collection
from ..models.api import ApiResponse, ReportRequest
from ..services.llm_service import generate_credit_report

router = APIRouter(prefix="/report", tags=["report"], dependencies=[Depends(verify_api_key)])


def _trace_id(x_request_id: str | None) -> str:
    return x_request_id or str(uuid4())


@router.post("/generate")
async def generate_report(
    payload: ReportRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return generate_credit_report(payload, _trace_id(x_request_id))


@router.post("/store")
async def store_report(
    payload: ReportRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    trace_id = _trace_id(x_request_id)
    try:
        await get_collection("score_reports_db").insert_one(
            {
                "user_id": payload.request_id or "anonymous",
                "generated_at": datetime.now(timezone.utc),
                "score": payload.score,
                "pillar_scores": payload.pillars,
                "language": payload.language,
            }
        )
        return ApiResponse(status="OK", data={"stored": True}, error=None, trace_id=trace_id)
    except Exception:
        return ApiResponse(
            status="ERROR",
            data={"stored": False},
            error="Failed to store report",
            trace_id=trace_id,
        )

