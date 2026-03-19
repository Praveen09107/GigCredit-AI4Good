"""Verification endpoints for GigCredit backend (simulation only)."""

from __future__ import annotations

from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, Header

from ..auth import verify_api_key
from ..models.api import ApiResponse, VerifyRequest
from ..services import gov_service

router = APIRouter(tags=["verify"], dependencies=[Depends(verify_api_key)])


def _trace_id(x_request_id: str | None) -> str:
    return x_request_id or str(uuid4())


@router.post("/gov/pan/verify")
@router.post("/verify/pan")
async def verify_pan(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_pan(payload, _trace_id(x_request_id))


@router.post("/gov/aadhaar/verify")
@router.post("/verify/aadhaar")
async def verify_aadhaar(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_aadhaar(payload, _trace_id(x_request_id))


@router.post("/bank/ifsc/verify")
@router.post("/verify/bank/ifsc")
async def verify_ifsc(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_ifsc(payload, _trace_id(x_request_id))


@router.post("/bank/account/verify")
@router.post("/verify/bank/account")
async def verify_bank_account(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_bank_account(payload, _trace_id(x_request_id))


@router.post("/gov/vehicle/rc/verify")
@router.post("/verify/vehicle/rc")
async def verify_vehicle_rc(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_vehicle_rc(payload, _trace_id(x_request_id))


@router.post("/gov/insurance/verify")
@router.post("/verify/insurance")
async def verify_insurance(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_insurance(payload, _trace_id(x_request_id))


@router.post("/gov/income-tax/itr/verify")
@router.post("/verify/income-tax/itr")
async def verify_itr(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_itr(payload, _trace_id(x_request_id))


@router.post("/gov/eshram/verify")
@router.post("/verify/eshram")
async def verify_eshram(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_eshram(payload, _trace_id(x_request_id))


@router.post("/bank/loan/check")
@router.post("/verify/loan")
async def verify_loan(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_loan(payload, _trace_id(x_request_id))

