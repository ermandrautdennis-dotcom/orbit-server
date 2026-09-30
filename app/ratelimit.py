"""Minimal in-memory sliding-window rate limiter (per-process, per-IP).

Good enough for a single Railway instance. If you scale to multiple replicas,
swap this for a Redis-backed limiter.
"""
from __future__ import annotations

import threading
import time
from collections import defaultdict, deque

from . import config

_lock = threading.Lock()
_hits: dict[str, deque[float]] = defaultdict(deque)


def check(identity: str) -> bool:
    """Return True if the request is allowed, False if it should be blocked."""
    now = time.time()
    window = config.RATE_LIMIT_WINDOW
    limit = config.RATE_LIMIT_MAX
    with _lock:
        dq = _hits[identity]
        while dq and dq[0] <= now - window:
            dq.popleft()
        if len(dq) >= limit:
            return False
        dq.append(now)
        return True
