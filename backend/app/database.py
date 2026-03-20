"""MongoDB connection helpers for the GigCredit backend."""

from __future__ import annotations

from typing import Any

from .config import settings
from .utils.logging import get_logger

_client: Any = None
_indexes_initialized = False
_logger = get_logger(__name__)

_INDEX_SPECS: tuple[tuple[str, str, bool], ...] = (
    ("users", "user_id", False),
    ("kyc_records", "identifier_hash", False),
    ("bank_records", "identifier_hash", False),
    ("utility_records", "identifier_hash", False),
    ("work_profiles", "user_id", False),
    ("work_profiles", "identifier_hash", False),
    ("scheme_records", "identifier_hash", False),
    ("insurance_records", "identifier_hash", False),
    ("itr_records", "identifier_hash", False),
    ("emi_records", "identifier_hash", False),
    ("reports", "request_id", False),
    ("pan_records", "pan_number", True),
    ("pan_db", "pan_number", True),
    ("aadhaar_records", "aadhaar_last4", False),
    ("aadhaar_db", "aadhaar_last4", False),
    ("bank_records", "ifsc_code", False),
    ("bank_records", "account_number_hash", False),
    ("bank_records", "loan_id", False),
    ("bank_records", "utility_type", False),
    ("ifsc_db", "ifsc_code", True),
    ("bank_accounts_db", "account_number_hash", True),
    ("vehicle_rc_db", "rc_number", True),
    ("insurance_db", "policy_number", True),
    ("itr_db", "itr_ack_number", True),
    ("gst_db", "gst_identifier", True),
    ("eshram_db", "eshram_number", True),
    ("svanidhi_db", "application_id", True),
    ("fssai_db", "license_number", True),
    ("skill_cert_db", "certificate_id", True),
    ("pmsym_db", "pmsym_ref", True),
    ("pmjjby_db", "pmjjby_ref", True),
    ("udyam_db", "udyam_ref", True),
    ("ppf_db", "ppf_account", True),
    ("loan_accounts_db", "loan_id", True),
    ("scheme_records", "eshram_number", False),
    ("scheme_records", "application_id", False),
    ("scheme_records", "license_number", False),
    ("scheme_records", "certificate_id", False),
    ("scheme_records", "pmsym_ref", False),
    ("scheme_records", "pmjjby_ref", False),
    ("scheme_records", "udyam_ref", False),
    ("scheme_records", "ppf_account", False),
)

_NON_UNIQUE_INDEX_SPECS: tuple[tuple[str, str], ...] = (
    ("verification_api_logs", "trace_id"),
    ("verification_api_logs", "verification_type"),
    ("report_api_logs", "trace_id"),
    ("report_api_logs", "request_id"),
    ("score_reports_db", "request_id"),
    ("score_reports_db", "generated_at"),
    ("audit_traces", "trace_id"),
    ("audit_traces", "path"),
)


def _motor_asyncio_module() -> Any:
    import importlib

    return importlib.import_module("motor.motor_asyncio")


def get_client() -> Any:
    global _client
    if _client is None:
        if "<db_password>" in settings.mongo_uri:
            _logger.warning(
                "Mongo URI contains placeholder '<db_password>'; database connectivity will fail until real credentials are configured."
            )
        motor_asyncio = _motor_asyncio_module()
        _client = motor_asyncio.AsyncIOMotorClient(
            settings.mongo_uri,
            serverSelectionTimeoutMS=3000,
        )
    return _client


def get_database() -> Any:
    client = get_client()
    return client[settings.mongo_db_name]


def get_collection(name: str) -> Any:
    return get_database()[name]


async def ensure_indexes() -> bool:
    global _indexes_initialized
    if _indexes_initialized:
        return True

    try:
        db = get_database()
        for collection, field, unique in _INDEX_SPECS:
            await db[collection].create_index(field, unique=unique)

        for collection, field in _NON_UNIQUE_INDEX_SPECS:
            await db[collection].create_index(field)

        await db["verification_api_logs"].create_index(
            "created_at",
            expireAfterSeconds=max(settings.verification_log_retention_days, 1) * 24 * 60 * 60,
        )
        await db["report_api_logs"].create_index(
            "created_at",
            expireAfterSeconds=max(settings.report_log_retention_days, 1) * 24 * 60 * 60,
        )
        await db["audit_traces"].create_index(
            "created_at",
            expireAfterSeconds=max(settings.audit_trace_retention_days, 1) * 24 * 60 * 60,
        )

        _indexes_initialized = True
        return True
    except Exception as exc:
        _logger.warning("Failed to ensure MongoDB indexes: %s", exc)
        return False


async def ping_database() -> bool:
    try:
        await get_database().command("ping")
        return True
    except Exception:
        return False


def indexes_ready() -> bool:
    return _indexes_initialized


def close_client() -> None:
    global _client, _indexes_initialized
    if _client is not None:
        _client.close()
        _client = None
    _indexes_initialized = False

