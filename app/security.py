"""Key generation, hashing, response signing, HWID normalisation."""
from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import time

from . import config

_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no ambiguous chars (0/O, 1/I)


def generate_key(prefix: str = "ORBIT", groups: int = 4, group_len: int = 5) -> str:
    """Return a human-readable license key, e.g. ORBIT-7K3PQ-...."""
    parts = [
        "".join(secrets.choice(_ALPHABET) for _ in range(group_len))
        for _ in range(groups)
    ]
    return f"{prefix}-" + "-".join(parts)


def hash_key(key: str) -> str:
    """Deterministic keyed hash used for DB lookups. Peppered, so a DB leak
    alone does not reveal usable keys."""
    normalized = key.strip().upper()
    return hmac.new(
        config.KEY_PEPPER.encode(),
        normalized.encode(),
        hashlib.sha256,
    ).hexdigest()


def normalize_hwid(hwid: str) -> str:
    """Trim + cap HWID length; hash anything unexpectedly long so we store a
    stable fixed-size identifier regardless of what the executor sends."""
    hwid = (hwid or "").strip()
    if len(hwid) > 128:
        return hashlib.sha256(hwid.encode()).hexdigest()
    return hwid


def sign_payload(body: str, ts: int | None = None) -> tuple[str, int]:
    """HMAC-sign a response body so the loader can verify authenticity.
    Returns (signature_b64, timestamp)."""
    ts = ts or int(time.time())
    mac = hmac.new(
        config.LOADER_SECRET.encode(),
        f"{ts}.{body}".encode(),
        hashlib.sha256,
    ).digest()
    return base64.b64encode(mac).decode(), ts


def constant_time_eq(a: str, b: str) -> bool:
    return hmac.compare_digest(a, b)
