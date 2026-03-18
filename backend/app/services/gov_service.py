"""Government and bank verification simulation services."""

from __future__ import annotations

import re
from typing import Any

from ..database import get_collection
from ..models.api import ApiResponse, VerifyRequest


def _normalize_identifier(identifier: str) -> str:
    return identifier.strip().upper()


def _mask_last4(value: str) -> str:
    clean = re.sub(r"\D", "", value)
    return clean[-4:] if len(clean) >= 4 else clean


def _invalid_response(error: str, trace_id: str | None) -> ApiResponse:
    return ApiResponse(status="INVALID", data=None, error=error, trace_id=trace_id)


def _error_response(error: str, trace_id: str | None) -> ApiResponse:
    return ApiResponse(status="ERROR", data=None, error=error, trace_id=trace_id)


def _found_response(data: dict[str, Any], trace_id: str | None) -> ApiResponse:
    return ApiResponse(status="FOUND", data=data, error=None, trace_id=trace_id)


def _not_found_response(trace_id: str | None) -> ApiResponse:
    return ApiResponse(status="NOT_FOUND", data=None, error=None, trace_id=trace_id)


async def _lookup(
    collection_name: str,
    query: dict[str, Any],
    projection: dict[str, int] | None,
    trace_id: str | None,
) -> ApiResponse:
    try:
        record = await get_collection(collection_name).find_one(query, projection)
    except Exception:
        return _error_response("Database error", trace_id)

    if record is None:
        return _not_found_response(trace_id)
    record.pop("_id", None)
    return _found_response(record, trace_id)


async def verify_pan(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    pan = _normalize_identifier(payload.identifier)
    if not re.fullmatch(r"[A-Z]{5}\d{4}[A-Z]", pan):
        return _invalid_response("Invalid PAN format", trace_id)
    return await _lookup(
        "pan_db",
        {"pan_number": pan},
        {"_id": 0, "pan_number": 1, "full_name": 1, "status": 1},
        trace_id,
    )


async def verify_aadhaar(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    aadhaar_last4 = _mask_last4(payload.identifier)
    if len(aadhaar_last4) != 4:
        return _invalid_response("Invalid Aadhaar format", trace_id)
    return await _lookup(
        "aadhaar_db",
        {"aadhaar_last4": aadhaar_last4},
        {"_id": 0, "aadhaar_last4": 1, "full_name": 1, "status": 1},
        trace_id,
    )


async def verify_ifsc(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    ifsc = _normalize_identifier(payload.identifier)
    if not re.fullmatch(r"[A-Z]{4}0[A-Z0-9]{6}", ifsc):
        return _invalid_response("Invalid IFSC format", trace_id)
    return await _lookup(
        "ifsc_db",
        {"ifsc_code": ifsc},
        {"_id": 0, "ifsc_code": 1, "bank_name": 1, "branch": 1},
        trace_id,
    )


async def verify_bank_account(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    account_hash = _normalize_identifier(payload.identifier)
    if len(account_hash) < 8:
        return _invalid_response("Invalid account identifier", trace_id)
    return await _lookup(
        "bank_accounts_db",
        {"account_number_hash": account_hash},
        {"_id": 0, "account_holder_name": 1, "ifsc_code": 1, "status": 1},
        trace_id,
    )


async def verify_vehicle_rc(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    rc_number = _normalize_identifier(payload.identifier)
    if len(rc_number) < 6:
        return _invalid_response("Invalid RC number", trace_id)
    return await _lookup(
        "vehicle_rc_db",
        {"rc_number": rc_number},
        {"_id": 0, "rc_number": 1, "owner_name": 1, "status": 1},
        trace_id,
    )


async def verify_insurance(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    policy = _normalize_identifier(payload.identifier)
    if len(policy) < 6:
        return _invalid_response("Invalid insurance policy number", trace_id)
    return await _lookup(
        "insurance_db",
        {"policy_number": policy},
        {"_id": 0, "policy_number": 1, "policy_type": 1, "status": 1},
        trace_id,
    )


async def verify_itr(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    itr_ack = _normalize_identifier(payload.identifier)
    if len(itr_ack) < 8:
        return _invalid_response("Invalid ITR acknowledgement number", trace_id)
    return await _lookup(
        "itr_db",
        {"itr_ack_number": itr_ack},
        {"_id": 0, "itr_ack_number": 1, "assessment_year": 1, "status": 1},
        trace_id,
    )


async def verify_eshram(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    eshram = _normalize_identifier(payload.identifier)
    if len(eshram) < 8:
        return _invalid_response("Invalid eShram number", trace_id)
    return await _lookup(
        "eshram_db",
        {"eshram_number": eshram},
        {"_id": 0, "eshram_number": 1, "status": 1},
        trace_id,
    )


async def verify_loan(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    loan_id = _normalize_identifier(payload.identifier)
    if len(loan_id) < 5:
        return _invalid_response("Invalid loan identifier", trace_id)
    return await _lookup(
        "loan_accounts_db",
        {"loan_id": loan_id},
        {"_id": 0, "loan_id": 1, "loan_status": 1, "emi_amount": 1, "lender": 1},
        trace_id,
    )

