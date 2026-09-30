"""ORM models."""
from __future__ import annotations

import datetime as dt

from sqlalchemy import BigInteger, DateTime, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


def _utcnow() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


class License(Base):
    __tablename__ = "licenses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # HMAC(pepper, key) hex digest — the plaintext key is never stored.
    key_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)

    # Which script bucket this key unlocks (see config.TIER_ORDER).
    tier: Mapped[str] = mapped_column(String(32), default="public")

    # HWID bound on first successful /api/script call. NULL until claimed.
    hwid: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    hwid_bound_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Discord user who claimed the key via /key (optional link).
    discord_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True, index=True)

    status: Mapped[str] = mapped_column(String(16), default="active")  # active | revoked
    note: Mapped[str] = mapped_column(String(255), default="")

    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    expires_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_used_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    uses: Mapped[int] = mapped_column(Integer, default=0)

    def is_expired(self) -> bool:
        if self.expires_at is None:
            return False
        exp = self.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=dt.timezone.utc)
        return _utcnow() >= exp
