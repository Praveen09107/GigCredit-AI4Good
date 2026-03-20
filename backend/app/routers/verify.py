"""Verification endpoints for GigCredit backend."""

from __future__ import annotations

from typing import Annotated, Any
from uuid import uuid4

from fastapi import APIRouter, Depends, Header

from ..auth import verify_api_key
from ..models.api import ApiResponse, VerifyRequest
from ..services import gov_service

router = APIRouter(tags=["verify"], dependencies=[Depends(verify_api_key)])


def _trace_id(x_request_id: str | None) -> str:
    return x_request_id or str(uuid4())


def _string_or_none(value: Any) -> str | None:
    if isinstance(value, str):
        trimmed = value.strip()
        return trimmed if trimmed else None
    return None


def _dict_or_none(value: Any) -> dict[str, Any] | None:
    return value if isinstance(value, dict) else None


def _normalize_loose_payload(
    payload: dict[str, Any],
    *,
    identifier_keys: tuple[str, ...],
) -> VerifyRequest | None:
    identifier: str | None = None
    for key in identifier_keys:
        identifier = _string_or_none(payload.get(key))
        if identifier:
            break

    if not identifier:
        return None

    return VerifyRequest(
        request_id=_string_or_none(payload.get("request_id")),
        identifier=identifier,
        context=_dict_or_none(payload.get("context")),
    )


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
@router.post("/verify/ifsc")
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


@router.post("/verify/bank_statement")
async def verify_bank_statement(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_bank_statement(payload, _trace_id(x_request_id))


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


@router.post("/gov/gst/verify")
@router.post("/verify/gst")
async def verify_gst(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_gst(payload, _trace_id(x_request_id))


@router.post("/gov/eshram/verify")
@router.post("/verify/eshram")
async def verify_eshram(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_eshram(payload, _trace_id(x_request_id))


@router.post("/gov/svanidhi/verify")
@router.post("/api/gov/svanidhi/verify")
@router.post("/verify/svanidhi")
async def verify_svanidhi(
    payload: dict[str, Any],
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    normalized = _normalize_loose_payload(
        payload,
        identifier_keys=("identifier", "application_id", "svanidhi_ref"),
    )
    if normalized is None:
        return ApiResponse(
            status="INVALID",
            data=None,
            error="Missing identifier/application_id/svanidhi_ref",
            trace_id=_trace_id(x_request_id),
        )
    return await gov_service.verify_svanidhi(normalized, _trace_id(x_request_id))


@router.post("/gov/fssai/verify")
@router.post("/api/gov/fssai/verify")
@router.post("/verify/fssai")
async def verify_fssai(
    payload: dict[str, Any],
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    normalized = _normalize_loose_payload(
        payload,
        identifier_keys=("identifier", "license_number", "fssai_number"),
    )
    if normalized is None:
        return ApiResponse(
            status="INVALID",
            data=None,
            error="Missing identifier/license_number/fssai_number",
            trace_id=_trace_id(x_request_id),
        )
    return await gov_service.verify_fssai(normalized, _trace_id(x_request_id))


@router.post("/gov/skill/verify")
@router.post("/api/gov/skill/verify")
@router.post("/verify/skill")
async def verify_skill_certificate(
    payload: dict[str, Any],
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    normalized = _normalize_loose_payload(
        payload,
        identifier_keys=("identifier", "certificate_id", "skill_certificate_id"),
    )
    if normalized is None:
        return ApiResponse(
            status="INVALID",
            data=None,
            error="Missing identifier/certificate_id/skill_certificate_id",
            trace_id=_trace_id(x_request_id),
        )
    return await gov_service.verify_skill_certificate(normalized, _trace_id(x_request_id))


@router.post("/gov/pmsym/verify")
@router.post("/verify/pmsym")
async def verify_pmsym(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_pmsym(payload, _trace_id(x_request_id))


@router.post("/gov/pmjjby/verify")
@router.post("/verify/pmjjby")
async def verify_pmjjby(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_pmjjby(payload, _trace_id(x_request_id))


@router.post("/gov/udyam/verify")
@router.post("/verify/udyam")
async def verify_udyam(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_udyam(payload, _trace_id(x_request_id))


@router.post("/gov/ppf/verify")
@router.post("/verify/ppf")
async def verify_ppf(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_ppf(payload, _trace_id(x_request_id))


@router.post("/bank/loan/check")
@router.post("/verify/loan")
async def verify_loan(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_loan(payload, _trace_id(x_request_id))


@router.post("/verify/utility")
async def verify_utility_bill(
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    return await gov_service.verify_utility_bill(payload, _trace_id(x_request_id))


@router.post("/verify/utility/{utility_type}")
async def verify_utility_bill_typed(
    utility_type: str,
    payload: VerifyRequest,
    x_request_id: Annotated[str | None, Header()] = None,
) -> ApiResponse:
    normalized_payload = VerifyRequest(
        request_id=payload.request_id,
        identifier=utility_type,
        context=payload.context,
    )
    return await gov_service.verify_utility_bill(normalized_payload, _trace_id(x_request_id))

