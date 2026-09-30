"""Core license logic: create, redeem+serve, link, revoke, reset.

These functions are shared by both the HTTP API and the Discord bot (they run
in the same process), so the business rules live in exactly one place.
"""
from __future__ import annotations

import datetime as dt
import os
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from . import config, security
from .models import License


def _utcnow() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


class LicenseError(Exception):
    """Raised with a client-safe message when a request must be rejected."""


@dataclass
class ScriptResult:
    script: str
    tier: str


# ── Script payload loading ──────────────────────────────────────────────
def load_script(tier: str) -> str:
    """Read the Lua payload for a tier from SCRIPTS_DIR/<tier>.lua."""
    path = os.path.join(config.SCRIPTS_DIR, f"{tier}.lua")
    if not os.path.isfile(path):
        raise LicenseError(f"no script configured for tier '{tier}'")
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


# ── Creation ────────────────────────────────────────────────────────────
def create_keys(
    db: Session,
    tier: str = "public",
    amount: int = 1,
    expires_days: int | None = None,
    note: str = "",
    discord_id: int | None = None,
) -> list[str]:
    """Generate `amount` keys, store their hashes, return the plaintext keys.
    The plaintext is returned exactly once here and never persisted."""
    if config.tier_rank(tier) < 0:
        raise LicenseError(f"unknown tier '{tier}'")

    expires_at = None
    if expires_days:
        expires_at = _utcnow() + dt.timedelta(days=expires_days)

    out: list[str] = []
    for _ in range(amount):
        # Retry on the astronomically unlikely hash collision.
        for _attempt in range(5):
            plain = security.generate_key()
            khash = security.hash_key(plain)
            if db.scalar(select(License.id).where(License.key_hash == khash)) is None:
                break
        else:
            raise LicenseError("could not generate a unique key, try again")

        db.add(
            License(
                key_hash=khash,
                tier=tier,
                expires_at=expires_at,
                note=note,
                discord_id=discord_id,
            )
        )
        out.append(plain)
    db.commit()
    return out


# ── Lookup ──────────────────────────────────────────────────────────────
def _find(db: Session, key: str) -> License | None:
    return db.scalar(select(License).where(License.key_hash == security.hash_key(key)))


def get_info(db: Session, key: str) -> License | None:
    return _find(db, key)


# ── Redeem + serve (called by the Lua loader) ───────────────────────────
def redeem_and_serve(db: Session, key: str, hwid: str, tier: str) -> ScriptResult:
    """Validate a key against an HWID and return the script for `tier`.

    First successful call binds the HWID permanently; every later call must
    present the same HWID or it is rejected. This is what stops a key from
    being shared across machines.
    """
    if config.tier_rank(tier) < 0:
        raise LicenseError("unknown tier")

    # Free tiers (the public script) are served to anyone, no key/HWID.
    if tier in config.FREE_TIERS:
        return ScriptResult(script=load_script(tier), tier=tier)

    lic = _find(db, key)
    if lic is None:
        raise LicenseError("invalid key")
    if lic.status != "active":
        raise LicenseError("key revoked")
    if lic.is_expired():
        raise LicenseError("key expired")

    hwid = security.normalize_hwid(hwid)
    if not hwid:
        raise LicenseError("missing hwid")

    if lic.hwid is None:
        # First redemption → lock this key to this machine.
        lic.hwid = hwid
        lic.hwid_bound_at = _utcnow()
    elif not security.constant_time_eq(lic.hwid, hwid):
        raise LicenseError("key already locked to another machine")

    # Tier gating: key can serve its own tier and anything below it.
    if config.tier_rank(tier) < 0:
        raise LicenseError("unknown tier")
    if config.tier_rank(tier) > config.tier_rank(lic.tier):
        raise LicenseError(f"key tier '{lic.tier}' cannot access '{tier}'")

    script = load_script(tier)

    lic.uses += 1
    lic.last_used_at = _utcnow()
    db.commit()
    return ScriptResult(script=script, tier=tier)


# ── Discord link (/key) ─────────────────────────────────────────────────
def link_discord(db: Session, key: str, discord_id: int) -> License:
    """Attach a Discord user to a key. Fails if it belongs to someone else."""
    lic = _find(db, key)
    if lic is None:
        raise LicenseError("invalid key")
    if lic.status != "active":
        raise LicenseError("key revoked")
    if lic.is_expired():
        raise LicenseError("key expired")
    if lic.discord_id and lic.discord_id != discord_id:
        raise LicenseError("key already claimed by another user")
    lic.discord_id = discord_id
    db.commit()
    return lic


# ── Admin ops ───────────────────────────────────────────────────────────
def reset_hwid(db: Session, key: str) -> License:
    lic = _find(db, key)
    if lic is None:
        raise LicenseError("invalid key")
    lic.hwid = None
    lic.hwid_bound_at = None
    db.commit()
    return lic


def revoke(db: Session, key: str) -> License:
    lic = _find(db, key)
    if lic is None:
        raise LicenseError("invalid key")
    lic.status = "revoked"
    db.commit()
    return lic


def unrevoke(db: Session, key: str) -> License:
    lic = _find(db, key)
    if lic is None:
        raise LicenseError("invalid key")
    lic.status = "active"
    db.commit()
    return lic
