"""Security-related helpers for GigCredit backend."""

from __future__ import annotations

import hashlib
import hmac
import time


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def hmac_sha256_hex(key: str, message: str) -> str:
    return hmac.new(key.encode("utf-8"), message.encode("utf-8"), hashlib.sha256).hexdigest()


def secure_compare(left: str, right: str) -> bool:
    return hmac.compare_digest(left, right)


def is_timestamp_within_window(timestamp_ms: int, window_seconds: int) -> bool:
    now_ms = int(time.time() * 1000)
    return abs(now_ms - timestamp_ms) <= window_seconds * 1000

