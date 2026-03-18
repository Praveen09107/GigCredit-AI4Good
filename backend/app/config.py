"""Configuration for the GigCredit backend."""

from __future__ import annotations

from dataclasses import dataclass
from os import getenv


@dataclass(frozen=True)
class Settings:
    mongo_uri: str
    mongo_db_name: str
    api_key: str
    gemini_api_key: str
    hmac_replay_window_seconds: int
    rate_limit_per_minute: int
    rate_limit_per_endpoint_per_minute: int
    rate_limit_burst_per_second: int


settings = Settings(
    mongo_uri=getenv("MONGO_URI", "mongodb://localhost:27017"),
    mongo_db_name=getenv("MONGO_DB_NAME", "gigcredit"),
    api_key=getenv("API_KEY", "gigcredit_dev_key"),
    gemini_api_key=getenv("GEMINI_API_KEY", ""),
    hmac_replay_window_seconds=int(getenv("HMAC_REPLAY_WINDOW_SECONDS", "300")),
    rate_limit_per_minute=int(getenv("RATE_LIMIT_PER_MINUTE", "60")),
    rate_limit_per_endpoint_per_minute=int(
        getenv("RATE_LIMIT_PER_ENDPOINT_PER_MINUTE", "10")
    ),
    rate_limit_burst_per_second=int(getenv("RATE_LIMIT_BURST_PER_SECOND", "5")),
)

