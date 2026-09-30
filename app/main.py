"""FastAPI entrypoint.

Starts the HTTP API and — in the same process — the Discord bot as a
background task, so a single Railway service runs the whole system.
"""
from __future__ import annotations

import asyncio
import contextlib
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from . import config
from .api import router
from .db import init_db

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("orbit")

_bot = None
_bot_task: asyncio.Task | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    log.info("database ready")

    global _bot, _bot_task
    if config.DISCORD_TOKEN:
        # Imported lazily so the API can boot even without discord installed.
        from bot.client import OrbitBot

        _bot = OrbitBot()
        _bot_task = asyncio.create_task(_run_bot(_bot))
        log.info("discord bot starting")
    else:
        log.warning("DISCORD_TOKEN not set — running API only, no bot")

    try:
        yield
    finally:
        if _bot is not None:
            await _bot.close()
        if _bot_task is not None:
            _bot_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await _bot_task


async def _run_bot(bot) -> None:
    try:
        await bot.start(config.DISCORD_TOKEN)
    except Exception:  # noqa: BLE001
        log.exception("discord bot crashed")


app = FastAPI(title="Orbit Auth", lifespan=lifespan)
app.include_router(router)


@app.get("/")
def health():
    return {"ok": True, "service": "orbit-auth"}
