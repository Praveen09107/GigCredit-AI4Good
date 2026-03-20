"""Configuration for the GigCredit backend."""

from __future__ import annotations

from dataclasses import dataclass
from os import getenv
from pathlib import Path

from dotenv import load_dotenv


_BACKEND_ROOT = Path(__file__).resolve().parents[1]
# Load .env defaults, but let process-level environment variables override them.
load_dotenv(_BACKEND_ROOT / ".env", override=False)


@dataclass(frozen=True)
class Settings:
    mongo_uri: str
    mongo_db_name: str
    api_key: str
    gemini_api_key: str
    require_production_readiness: bool
    hmac_replay_window_seconds: int
    rate_limit_per_minute: int
    rate_limit_per_endpoint_per_minute: int
    rate_limit_burst_per_second: int
    verification_log_retention_days: int
    report_log_retention_days: int
    audit_trace_retention_days: int


settings = Settings(
    mongo_uri=getenv("MONGO_URI", "mongodb://localhost:27017"),
    mongo_db_name=getenv("MONGO_DB_NAME", "gigcredit"),
    api_key=getenv("API_KEY", "gigcredit_dev_key"),
    gemini_api_key=getenv("GEMINI_API_KEY", ""),
    require_production_readiness=getenv("GIGCREDIT_REQUIRE_PRODUCTION_READINESS", "false").lower() == "true",
    hmac_replay_window_seconds=int(getenv("HMAC_REPLAY_WINDOW_SECONDS", "300")),
    rate_limit_per_minute=int(getenv("RATE_LIMIT_PER_MINUTE", "60")),
    rate_limit_per_endpoint_per_minute=int(
        getenv("RATE_LIMIT_PER_ENDPOINT_PER_MINUTE", "10")
    ),
    rate_limit_burst_per_second=int(getenv("RATE_LIMIT_BURST_PER_SECOND", "5")),
    verification_log_retention_days=int(getenv("VERIFICATION_LOG_RETENTION_DAYS", "90")),
    report_log_retention_days=int(getenv("REPORT_LOG_RETENTION_DAYS", "180")),
    audit_trace_retention_days=int(getenv("AUDIT_TRACE_RETENTION_DAYS", "30")),
)

