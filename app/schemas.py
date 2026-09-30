"""Pydantic request/response models."""
from __future__ import annotations

from pydantic import BaseModel, Field


class ScriptRequest(BaseModel):
    key: str = Field(min_length=4, max_length=128)
    hwid: str = Field(min_length=1, max_length=512)
    tier: str = Field(default="public", max_length=32)


class ScriptResponse(BaseModel):
    ok: bool
    script: str
    tier: str
    sig: str
    ts: int


class ErrorResponse(BaseModel):
    ok: bool = False
    error: str


# ── Admin API ───────────────────────────────────────────────────────────
class GenKeyRequest(BaseModel):
    tier: str = "public"
    amount: int = Field(default=1, ge=1, le=500)
    expires_days: int | None = Field(default=None, ge=1, le=3650)
    note: str = Field(default="", max_length=255)


class KeyInfo(BaseModel):
    key: str | None = None  # only present right after generation
    tier: str
    status: str
    hwid_bound: bool
    discord_id: int | None
    uses: int
    note: str
