"""Central configuration loaded from environment variables.

Every secret is read from the environment so nothing sensitive lives in the
repo. On Railway set these under the service's "Variables" tab.
"""
from __future__ import annotations

import os
from dotenv import load_dotenv

load_dotenv()


def _get(name: str, default: str | None = None, required: bool = False) -> str:
    val = os.getenv(name, default)
    if required and not val:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return val or ""


# ── HTTP ────────────────────────────────────────────────────────────────
PORT = int(os.getenv("PORT", "8000"))

# Public base URL of this deployment, e.g. https://orbit.up.railway.app
# Used to render the loader snippet handed out by the Discord panel.
BASE_URL = _get("BASE_URL", "https://your-app.up.railway.app").rstrip("/")

# ── Database ────────────────────────────────────────────────────────────
# If DATABASE_URL is set (Railway Postgres plugin) it is used directly.
# Otherwise we fall back to a SQLite file. On Railway attach a Volume and
# point SQLITE_PATH at it (e.g. /data/orbit.db) so keys/HWIDs survive
# redeploys — the default container filesystem is ephemeral.
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
SQLITE_PATH = _get("SQLITE_PATH", "orbit.db")

# ── Cryptographic secrets ───────────────────────────────────────────────
# Pepper mixed into key hashing. Keys are NEVER stored in plaintext.
KEY_PEPPER = _get("KEY_PEPPER", "dev-pepper-change-me")
# Shared secret used to HMAC-sign script responses so a client can verify
# the payload really came from this server (anti man-in-the-middle / spoof).
LOADER_SECRET = _get("LOADER_SECRET", "dev-loader-secret-change-me")
# Bearer token guarding the /admin HTTP API.
ADMIN_TOKEN = _get("ADMIN_TOKEN", "dev-admin-token-change-me")

# ── Discord ─────────────────────────────────────────────────────────────
DISCORD_TOKEN = _get("DISCORD_TOKEN")
# Guild to register slash commands into instantly (dev). Empty = global sync.
DISCORD_GUILD_ID = os.getenv("DISCORD_GUILD_ID", "").strip()
# Role allowed to run admin commands (/genkey, /resethwid, ...).
# Empty means "Administrator permission required".
ADMIN_ROLE_ID = os.getenv("ADMIN_ROLE_ID", "").strip()
# Channel where generated keys / audit events are logged.
LOG_CHANNEL_ID = os.getenv("LOG_CHANNEL_ID", "").strip()

# ── Scripts ─────────────────────────────────────────────────────────────
# Directory holding the Lua payloads served per tier: <tier>.lua
SCRIPTS_DIR = _get("SCRIPTS_DIR", "scripts")

# Tier hierarchy: a higher tier can pull every script at or below its level.
# Add or rename tiers freely — the names here are the ones the panel exposes.
TIER_ORDER = ["public", "premium"]

# Tiers served to anyone without a key (the free "public" script). Premium
# tiers are NOT listed here, so they stay key- and HWID-locked.
FREE_TIERS = [t.strip() for t in os.getenv("FREE_TIERS", "public").split(",") if t.strip()]

# ── Rate limiting (simple in-memory, per-process) ───────────────────────
RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW", "60"))   # seconds
RATE_LIMIT_MAX = int(os.getenv("RATE_LIMIT_MAX", "30"))          # req/window/ip


def tier_rank(tier: str) -> int:
    try:
        return TIER_ORDER.index(tier)
    except ValueError:
        return -1
