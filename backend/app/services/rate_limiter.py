"""Simple in-memory rate limiter for GigCredit backend."""

from __future__ import annotations

import time
from collections import defaultdict, deque

from ..config import settings

_global_minute_buckets: dict[str, deque[float]] = defaultdict(deque)
_endpoint_minute_buckets: dict[tuple[str, str], deque[float]] = defaultdict(deque)
_burst_second_buckets: dict[str, deque[float]] = defaultdict(deque)


def _prune(bucket: deque[float], cutoff: float) -> None:
    while bucket and bucket[0] < cutoff:
        bucket.popleft()


def check_rate_limit(device_id: str, endpoint: str) -> bool:
    now = time.time()

    global_bucket = _global_minute_buckets[device_id]
    endpoint_bucket = _endpoint_minute_buckets[(device_id, endpoint)]
    burst_bucket = _burst_second_buckets[device_id]

    _prune(global_bucket, now - 60.0)
    _prune(endpoint_bucket, now - 60.0)
    _prune(burst_bucket, now - 1.0)

    if len(global_bucket) >= settings.rate_limit_per_minute:
        return False
    if len(endpoint_bucket) >= settings.rate_limit_per_endpoint_per_minute:
        return False
    if len(burst_bucket) >= settings.rate_limit_burst_per_second:
        return False

    global_bucket.append(now)
    endpoint_bucket.append(now)
    burst_bucket.append(now)
    return True

