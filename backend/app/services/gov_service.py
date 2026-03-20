"""Government and bank verification services."""

from __future__ import annotations

from datetime import datetime, timezone
import hashlib
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


def _hash_value(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:16]


def _redact_identifier(identifier: str) -> str:
    normalized = identifier.strip()
    if not normalized:
        return ""
    return f"sha256:{_hash_value(normalized)}"


def _sanitize_response_data(data: Any) -> Any:
    if not isinstance(data, dict):
        return data

    redacted: dict[str, Any] = {}
    sensitive_hints = (
        "identifier",
        "number",
        "account",
        "aadhaar",
        "pan",
        "policy",
        "license",
        "certificate",
        "ack",
        "ref",
        "id",
    )

    for key, value in data.items():
        key_lower = key.lower()
        if isinstance(value, str) and any(hint in key_lower for hint in sensitive_hints):
            redacted[key] = _redact_identifier(value)
            continue

        if isinstance(value, str):
            redacted[key] = value[:128]
            continue

        if isinstance(value, (int, float, bool)) or value is None:
            redacted[key] = value
            continue

        redacted[key] = str(value)[:128]

    return redacted


async def _audit_verification_event(
    *,
    verification_type: str,
    identifier: str,
    response: ApiResponse,
    collection_name: str | None = None,
) -> None:
    try:
        safe_identifier = _redact_identifier(identifier)
        await get_collection("verification_api_logs").insert_one(
            {
                "verification_type": verification_type,
                "identifier_hash": safe_identifier,
                "collection_name": collection_name,
                "status": response.status,
                "error": response.error,
                "trace_id": response.trace_id,
                "data": _sanitize_response_data(response.data),
                "created_at": datetime.now(timezone.utc),
            }
        )
    except Exception:
        # Never fail verification response due to audit write issues.
        return


async def _write_canonical_collection(
    *,
    verification_type: str,
    identifier: str,
    response: ApiResponse,
    context: dict[str, Any] | None,
) -> None:
    collection_by_type = {
        "pan": "kyc_records",
        "aadhaar": "kyc_records",
        "ifsc": "bank_records",
        "bank_account": "bank_records",
        "bank_statement": "bank_records",
        "vehicle_rc": "work_profiles",
        "loan": "emi_records",
        "utility": "utility_records",
        "insurance": "insurance_records",
        "itr": "itr_records",
        "gst": "itr_records",
        "eshram": "scheme_records",
        "svanidhi": "scheme_records",
        "fssai": "scheme_records",
        "skill_certificate": "scheme_records",
        "pmsym": "scheme_records",
        "pmjjby": "scheme_records",
        "udyam": "scheme_records",
        "ppf": "scheme_records",
    }

    collection_name = collection_by_type.get(verification_type)
    if not collection_name:
        return

    try:
        await get_collection(collection_name).insert_one(
            {
                "verification_type": verification_type,
                "identifier_hash": _redact_identifier(identifier),
                "status": response.status,
                "trace_id": response.trace_id,
                "error": response.error,
                "context": _sanitize_response_data(context or {}),
                "response": _sanitize_response_data(response.data or {}),
                "created_at": datetime.now(timezone.utc),
            }
        )
    except Exception:
        return


async def _lookup(
    verification_type: str,
    collection_names: list[str],
    query: dict[str, Any],
    projection: dict[str, int] | None,
    trace_id: str | None,
) -> ApiResponse:
    db_error = False
    matched_collection: str | None = None
    record: dict[str, Any] | None = None

    for collection_name in collection_names:
        try:
            record = await get_collection(collection_name).find_one(query, projection)
            if record is not None:
                matched_collection = collection_name
                break
        except Exception:
            db_error = True
            continue

    if record is None and db_error:
        response = _error_response("Database error", trace_id)
        await _write_canonical_collection(
            verification_type=verification_type,
            identifier=str(query),
            response=response,
            context=None,
        )
        await _audit_verification_event(
            verification_type=verification_type,
            identifier=str(query.get("identifier") or query),
            response=response,
            collection_name=matched_collection,
        )
        return response

    if record is None:
        response = _not_found_response(trace_id)
        await _write_canonical_collection(
            verification_type=verification_type,
            identifier=str(query),
            response=response,
            context=None,
        )
        await _audit_verification_event(
            verification_type=verification_type,
            identifier=str(query),
            response=response,
            collection_name=matched_collection,
        )
        return response

    record.pop("_id", None)
    response = _found_response(record, trace_id)
    await _write_canonical_collection(
        verification_type=verification_type,
        identifier=str(query),
        response=response,
        context=None,
    )
    await _audit_verification_event(
        verification_type=verification_type,
        identifier=str(query),
        response=response,
        collection_name=matched_collection,
    )
    return response


def _collections(*names: str) -> list[str]:
    # Keep first name as the production collection contract and fall back
    # to legacy collections for backward compatibility during migration.
    return [name for name in names if name]


async def _lookup_single(
    verification_type: str,
    collection_name: str,
    query: dict[str, Any],
    projection: dict[str, int] | None,
    trace_id: str | None,
) -> ApiResponse:
    return await _lookup(
        verification_type=verification_type,
        collection_names=_collections(collection_name),
        query=query,
        projection=projection,
        trace_id=trace_id,
    )


async def _lookup_with_fallbacks(
    verification_type: str,
    collection_names: list[str],
    query: dict[str, Any],
    projection: dict[str, int] | None,
    trace_id: str | None,
) -> ApiResponse:
    return await _lookup(
        verification_type=verification_type,
        collection_names=collection_names,
        query=query,
        projection=projection,
        trace_id=trace_id,
    )


async def verify_pan(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    pan = _normalize_identifier(payload.identifier)
    if not re.fullmatch(r"[A-Z]{5}\d{4}[A-Z]", pan):
        response = _invalid_response("Invalid PAN format", trace_id)
        await _audit_verification_event(verification_type="pan", identifier=pan, response=response)
        return response
    return await _lookup_with_fallbacks(
        "pan",
        _collections("pan_records", "pan_db"),
        {"pan_number": pan},
        {"_id": 0, "pan_number": 1, "full_name": 1, "status": 1},
        trace_id,
    )


async def verify_aadhaar(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    aadhaar_last4 = _mask_last4(payload.identifier)
    if len(aadhaar_last4) != 4:
        response = _invalid_response("Invalid Aadhaar format", trace_id)
        await _audit_verification_event(verification_type="aadhaar", identifier=aadhaar_last4, response=response)
        return response
    return await _lookup_with_fallbacks(
        "aadhaar",
        _collections("aadhaar_records", "aadhaar_db"),
        {"aadhaar_last4": aadhaar_last4},
        {"_id": 0, "aadhaar_last4": 1, "full_name": 1, "status": 1},
        trace_id,
    )


async def verify_ifsc(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    ifsc = _normalize_identifier(payload.identifier)
    if not re.fullmatch(r"[A-Z]{4}0[A-Z0-9]{6}", ifsc):
        response = _invalid_response("Invalid IFSC format", trace_id)
        await _audit_verification_event(verification_type="ifsc", identifier=ifsc, response=response)
        return response
    return await _lookup_with_fallbacks(
        "ifsc",
        _collections("bank_records", "ifsc_db"),
        {"ifsc_code": ifsc},
        {"_id": 0, "ifsc_code": 1, "bank_name": 1, "branch": 1},
        trace_id,
    )


async def verify_bank_account(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    account_hash = _normalize_identifier(payload.identifier)
    if len(account_hash) < 8:
        response = _invalid_response("Invalid account identifier", trace_id)
        await _audit_verification_event(verification_type="bank_account", identifier=account_hash, response=response)
        return response
    return await _lookup_with_fallbacks(
        "bank_account",
        _collections("bank_records", "bank_accounts_db"),
        {"account_number_hash": account_hash},
        {"_id": 0, "account_holder_name": 1, "ifsc_code": 1, "status": 1},
        trace_id,
    )


async def verify_vehicle_rc(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    rc_number = _normalize_identifier(payload.identifier)
    if len(rc_number) < 6:
        response = _invalid_response("Invalid RC number", trace_id)
        await _audit_verification_event(verification_type="vehicle_rc", identifier=rc_number, response=response)
        return response
    return await _lookup_single(
        "vehicle_rc",
        "vehicle_rc_db",
        {"rc_number": rc_number},
        {"_id": 0, "rc_number": 1, "owner_name": 1, "status": 1},
        trace_id,
    )


async def verify_insurance(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    policy = _normalize_identifier(payload.identifier)
    if len(policy) < 6:
        response = _invalid_response("Invalid insurance policy number", trace_id)
        await _audit_verification_event(verification_type="insurance", identifier=policy, response=response)
        return response
    return await _lookup_single(
        "insurance",
        "insurance_db",
        {"policy_number": policy},
        {"_id": 0, "policy_number": 1, "policy_type": 1, "status": 1},
        trace_id,
    )


async def verify_itr(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    itr_ack = _normalize_identifier(payload.identifier)
    if len(itr_ack) < 8:
        response = _invalid_response("Invalid ITR acknowledgement number", trace_id)
        await _audit_verification_event(verification_type="itr", identifier=itr_ack, response=response)
        return response
    return await _lookup_single(
        "itr",
        "itr_db",
        {"itr_ack_number": itr_ack},
        {"_id": 0, "itr_ack_number": 1, "assessment_year": 1, "status": 1},
        trace_id,
    )


async def verify_gst(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    gst_identifier = _normalize_identifier(payload.identifier)
    if len(gst_identifier) < 8:
        response = _invalid_response("Invalid GST identifier", trace_id)
        await _audit_verification_event(verification_type="gst", identifier=gst_identifier, response=response)
        return response

    return await _lookup_single(
        "gst",
        "gst_db",
        {"gst_identifier": gst_identifier},
        {"_id": 0, "gst_identifier": 1, "status": 1, "legal_name": 1},
        trace_id,
    )


async def verify_eshram(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    eshram = _normalize_identifier(payload.identifier)
    if len(eshram) < 8:
        response = _invalid_response("Invalid eShram number", trace_id)
        await _audit_verification_event(verification_type="eshram", identifier=eshram, response=response)
        return response
    return await _lookup_with_fallbacks(
        "eshram",
        _collections("scheme_records", "eshram_db"),
        {"eshram_number": eshram},
        {"_id": 0, "eshram_number": 1, "status": 1},
        trace_id,
    )


async def verify_svanidhi(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    application_id = _normalize_identifier(payload.identifier)
    if len(application_id) < 6:
        response = _invalid_response("Invalid SVANidhi application id", trace_id)
        await _audit_verification_event(verification_type="svanidhi", identifier=application_id, response=response)
        return response

    return await _lookup_with_fallbacks(
        "svanidhi",
        _collections("scheme_records", "svanidhi_db"),
        {"application_id": application_id},
        {"_id": 0, "application_id": 1, "status": 1},
        trace_id,
    )


async def verify_fssai(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    license_number = _normalize_identifier(payload.identifier)
    if not re.fullmatch(r"\d{14}", license_number):
        response = _invalid_response("Invalid FSSAI license number", trace_id)
        await _audit_verification_event(verification_type="fssai", identifier=license_number, response=response)
        return response

    return await _lookup_with_fallbacks(
        "fssai",
        _collections("scheme_records", "fssai_db"),
        {"license_number": license_number},
        {"_id": 0, "license_number": 1, "status": 1},
        trace_id,
    )


async def verify_skill_certificate(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    certificate_id = _normalize_identifier(payload.identifier)
    if len(certificate_id) < 6:
        response = _invalid_response("Invalid skill certificate id", trace_id)
        await _audit_verification_event(
            verification_type="skill_certificate",
            identifier=certificate_id,
            response=response,
        )
        return response

    return await _lookup_with_fallbacks(
        "skill_certificate",
        _collections("scheme_records", "skill_cert_db"),
        {"certificate_id": certificate_id},
        {"_id": 0, "certificate_id": 1, "status": 1},
        trace_id,
    )


async def verify_pmsym(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    pmsym_ref = _normalize_identifier(payload.identifier)
    if len(pmsym_ref) < 6:
        response = _invalid_response("Invalid PM-SYM reference", trace_id)
        await _audit_verification_event(verification_type="pmsym", identifier=pmsym_ref, response=response)
        return response

    return await _lookup_with_fallbacks(
        "pmsym",
        _collections("scheme_records", "pmsym_db"),
        {"pmsym_ref": pmsym_ref},
        {"_id": 0, "pmsym_ref": 1, "status": 1},
        trace_id,
    )


async def verify_pmjjby(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    pmjjby_ref = _normalize_identifier(payload.identifier)
    if len(pmjjby_ref) < 6:
        response = _invalid_response("Invalid PMJJBY reference", trace_id)
        await _audit_verification_event(verification_type="pmjjby", identifier=pmjjby_ref, response=response)
        return response

    return await _lookup_with_fallbacks(
        "pmjjby",
        _collections("scheme_records", "pmjjby_db"),
        {"pmjjby_ref": pmjjby_ref},
        {"_id": 0, "pmjjby_ref": 1, "status": 1},
        trace_id,
    )


async def verify_udyam(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    udyam_ref = _normalize_identifier(payload.identifier)
    if len(udyam_ref) < 6:
        response = _invalid_response("Invalid UDYAM reference", trace_id)
        await _audit_verification_event(verification_type="udyam", identifier=udyam_ref, response=response)
        return response

    return await _lookup_with_fallbacks(
        "udyam",
        _collections("scheme_records", "udyam_db"),
        {"udyam_ref": udyam_ref},
        {"_id": 0, "udyam_ref": 1, "status": 1},
        trace_id,
    )


async def verify_ppf(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    ppf_account = _normalize_identifier(payload.identifier)
    if len(ppf_account) < 6:
        response = _invalid_response("Invalid PPF account reference", trace_id)
        await _audit_verification_event(verification_type="ppf", identifier=ppf_account, response=response)
        return response

    return await _lookup_with_fallbacks(
        "ppf",
        _collections("scheme_records", "ppf_db"),
        {"ppf_account": ppf_account},
        {"_id": 0, "ppf_account": 1, "status": 1},
        trace_id,
    )


async def verify_loan(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    loan_id = _normalize_identifier(payload.identifier)
    if len(loan_id) < 5:
        response = _invalid_response("Invalid loan identifier", trace_id)
        await _audit_verification_event(verification_type="loan", identifier=loan_id, response=response)
        return response
    return await _lookup_with_fallbacks(
        "loan",
        _collections("bank_records", "loan_accounts_db"),
        {"loan_id": loan_id},
        {"_id": 0, "loan_id": 1, "loan_status": 1, "emi_amount": 1, "lender": 1},
        trace_id,
    )


async def verify_utility_bill(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    utility_type = _normalize_identifier(payload.identifier)
    allowed = {"ELECTRICITY", "LPG", "MOBILE", "RENT", "WIFI", "OTT"}
    if utility_type not in allowed:
        response = _invalid_response("Invalid utility type", trace_id)
        await _audit_verification_event(verification_type="utility", identifier=utility_type, response=response)
        return response

    return await _lookup_with_fallbacks(
        "utility",
        _collections("bank_records", "utility_bills_db"),
        {"utility_type": utility_type, "status": "ACTIVE"},
        {"_id": 0, "utility_type": 1, "status": 1, "validation_mode": 1},
        trace_id,
    )


async def verify_bank_statement(payload: VerifyRequest, trace_id: str | None) -> ApiResponse:
    context = payload.context or {}
    transaction_count = context.get("transaction_count")
    from_date = context.get("from_date")
    to_date = context.get("to_date")

    if not isinstance(transaction_count, int) or transaction_count <= 0:
        response = _invalid_response("Invalid bank statement payload: transaction_count is required", trace_id)
        await _write_canonical_collection(
            verification_type="bank_statement",
            identifier=payload.identifier,
            response=response,
            context=context,
        )
        await _audit_verification_event(
            verification_type="bank_statement",
            identifier=payload.identifier,
            response=response,
        )
        return response

    days_span = None
    if isinstance(from_date, str) and isinstance(to_date, str):
        try:
            start = datetime.fromisoformat(from_date)
            end = datetime.fromisoformat(to_date)
            days_span = abs((end - start).days)
        except ValueError:
            days_span = None

    is_valid = transaction_count >= 30 and (days_span is None or days_span >= 180)
    response = _found_response(
        {
            "verified": is_valid,
            "transaction_count": transaction_count,
            "statement_days": days_span,
        },
        trace_id,
    )
    if not is_valid:
        response = _invalid_response("Bank statement failed minimum validation checks", trace_id)

    await _write_canonical_collection(
        verification_type="bank_statement",
        identifier=payload.identifier,
        response=response,
        context=context,
    )
    await _audit_verification_event(
        verification_type="bank_statement",
        identifier=payload.identifier,
        response=response,
    )
    return response

