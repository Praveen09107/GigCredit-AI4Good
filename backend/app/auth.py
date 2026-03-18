"""
Authentication and rate-limiting middleware for the GigCredit backend.

NOTE: This is a skeleton; full HMAC and rate limiting logic will be
implemented according to `planning/2_BACKEND_HARDENING_SPEC.md`.
"""

from fastapi import Request


async def verify_api_key(request: Request) -> None:
    """
    Placeholder dependency for API key + HMAC validation.
    """
    # Full implementation will validate:
    # - X-API-Key
    # - X-Device-ID
    # - X-Timestamp
    # - X-Signature
    # and apply rate limits.
    return None

