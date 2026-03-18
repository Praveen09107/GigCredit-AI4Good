"""Authentication and rate-limiting dependency for the GigCredit backend."""

from __future__ import annotations

from fastapi import HTTPException, Request, status

from .config import settings
from .services.rate_limiter import check_rate_limit
from .utils.security import (
    hmac_sha256_hex,
    is_timestamp_within_window,
    secure_compare,
    sha256_hex,
)


async def verify_api_key(request: Request) -> None:
    api_key = request.headers.get("X-API-Key")
    device_id = request.headers.get("X-Device-ID")
    timestamp = request.headers.get("X-Timestamp")
    signature = request.headers.get("X-Signature")

    if not api_key or not device_id or not timestamp or not signature:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication headers",
        )

    if api_key != settings.api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

    try:
        timestamp_ms = int(timestamp)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid timestamp",
        ) from exc

    if not is_timestamp_within_window(
        timestamp_ms=timestamp_ms,
        window_seconds=settings.hmac_replay_window_seconds,
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Timestamp outside replay window",
        )

    body_bytes = await request.body()
    body_hash = sha256_hex(body_bytes)
    message = f"{device_id}{timestamp}{body_hash}"
    expected_signature = hmac_sha256_hex(api_key, message)

    if not secure_compare(signature, expected_signature):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid request signature",
        )

    if not check_rate_limit(device_id=device_id, endpoint=request.url.path):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded",
        )

