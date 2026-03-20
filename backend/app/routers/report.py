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
    trace_id = _trace_id(x_request_id)
    response = generate_credit_report(payload, trace_id)
    try:
        user_id = payload.request_id or "anonymous"
        await get_collection("users").update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "user_id": user_id,
                    "last_activity_at": datetime.now(timezone.utc),
                    "last_report_trace_id": trace_id,
                }
            },
            upsert=True,
        )
        await get_collection("work_profiles").update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "user_id": user_id,
                    "last_report_trace_id": trace_id,
                    "last_report_generated_at": datetime.now(timezone.utc),
                }
            },
            upsert=True,
        )
        await get_collection("reports").insert_one(
            {
                "request_id": payload.request_id,
                "trace_id": trace_id,
                "score": payload.score,
                "language": payload.language,
                "status": response.status,
                "error": response.error,
                "created_at": datetime.now(timezone.utc),
            }
        )
        await get_collection("report_api_logs").insert_one(
            {
                "event": "generate",
                "request_id": payload.request_id,
                "trace_id": trace_id,
                "status": response.status,
                "error": response.error,
                "created_at": datetime.now(timezone.utc),
            }
        )
    except Exception:
        pass
    return response


@router.post("/store")
async def store_report(
    payload: ReportRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    trace_id = _trace_id(x_request_id)
    try:
        user_id = payload.request_id or "anonymous"
        await get_collection("users").update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "user_id": user_id,
                    "last_activity_at": datetime.now(timezone.utc),
                    "last_report_trace_id": trace_id,
                }
            },
            upsert=True,
        )
        await get_collection("work_profiles").update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "user_id": user_id,
                    "last_report_trace_id": trace_id,
                    "last_report_generated_at": datetime.now(timezone.utc),
                }
            },
            upsert=True,
        )
        await get_collection("reports").insert_one(
            {
                "user_id": user_id,
                "request_id": payload.request_id,
                "trace_id": trace_id,
                "generated_at": datetime.now(timezone.utc),
                "score": payload.score,
                "pillars": payload.pillars,
                "language": payload.language,
            }
        )
        await get_collection("score_reports_db").insert_one(
            {
                "user_id": payload.request_id or "anonymous",
                "request_id": payload.request_id,
                "trace_id": trace_id,
                "generated_at": datetime.now(timezone.utc),
                "score": payload.score,
                "pillar_scores": payload.pillars,
                "language": payload.language,
            }
        )
        await get_collection("report_api_logs").insert_one(
            {
                "event": "store",
                "request_id": payload.request_id,
                "trace_id": trace_id,
                "status": "OK",
                "error": None,
                "created_at": datetime.now(timezone.utc),
            }
        )
        return ApiResponse(status="OK", data={"stored": True}, error=None, trace_id=trace_id)
    except Exception:
        try:
            await get_collection("report_api_logs").insert_one(
                {
                    "event": "store",
                    "request_id": payload.request_id,
                    "trace_id": trace_id,
                    "status": "ERROR",
                    "error": "Failed to store report",
                    "created_at": datetime.now(timezone.utc),
                }
            )
        except Exception:
            pass
        return ApiResponse(
            status="ERROR",
            data={"stored": False},
            error="Failed to store report",
            trace_id=trace_id,
        )

