"""HTTP API: public script endpoint + protected admin endpoints."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import config, licensing, security
from .db import get_session
from .models import License
from .ratelimit import check as rl_check
from .schemas import GenKeyRequest, ScriptRequest, ScriptResponse

router = APIRouter()


def _client_ip(request: Request) -> str:
    # Railway sits behind a proxy; trust the first X-Forwarded-For hop.
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


# ── Public: the Lua loader hits this ────────────────────────────────────
@router.post("/api/script", response_model=ScriptResponse)
def get_script(
    payload: ScriptRequest,
    request: Request,
    db: Session = Depends(get_session),
):
    if not rl_check(_client_ip(request)):
        raise HTTPException(status_code=429, detail="rate limited")

    try:
        result = licensing.redeem_and_serve(
            db, payload.key, payload.hwid, payload.tier
        )
    except licensing.LicenseError as exc:
        # Uniform 403 so probing can't distinguish failure modes by status.
        raise HTTPException(status_code=403, detail=str(exc))

    sig, ts = security.sign_payload(result.script)
    return ScriptResponse(
        ok=True, script=result.script, tier=result.tier, sig=sig, ts=ts
    )


# ── Admin auth dependency ───────────────────────────────────────────────
def require_admin(authorization: str = Header(default="")) -> None:
    expected = f"Bearer {config.ADMIN_TOKEN}"
    if not security.constant_time_eq(authorization, expected):
        raise HTTPException(status_code=401, detail="unauthorized")


@router.post("/admin/keys", dependencies=[Depends(require_admin)])
def admin_generate(body: GenKeyRequest, db: Session = Depends(get_session)):
    try:
        keys = licensing.create_keys(
            db,
            tier=body.tier,
            amount=body.amount,
            expires_days=body.expires_days,
            note=body.note,
        )
    except licensing.LicenseError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"ok": True, "tier": body.tier, "keys": keys}


@router.post("/admin/revoke", dependencies=[Depends(require_admin)])
def admin_revoke(key: str, db: Session = Depends(get_session)):
    try:
        licensing.revoke(db, key)
    except licensing.LicenseError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return {"ok": True}


@router.post("/admin/reset-hwid", dependencies=[Depends(require_admin)])
def admin_reset_hwid(key: str, db: Session = Depends(get_session)):
    try:
        licensing.reset_hwid(db, key)
    except licensing.LicenseError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return {"ok": True}


@router.get("/admin/stats", dependencies=[Depends(require_admin)])
def admin_stats(db: Session = Depends(get_session)):
    total = db.scalar(select(License.id).limit(1))
    rows = db.execute(select(License.tier, License.status, License.hwid)).all()
    stats = {
        "total": len(rows),
        "active": sum(1 for r in rows if r.status == "active"),
        "revoked": sum(1 for r in rows if r.status == "revoked"),
        "bound": sum(1 for r in rows if r.hwid is not None),
        "by_tier": {},
    }
    for r in rows:
        stats["by_tier"][r.tier] = stats["by_tier"].get(r.tier, 0) + 1
    return {"ok": True, "stats": stats, "_has_rows": total is not None}
