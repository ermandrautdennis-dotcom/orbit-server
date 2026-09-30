# Orbit Auth

A fast, HWID-locked license system for distributing Lua scripts, with a Discord
bot panel and `/key` redeemer. FastAPI + SQLAlchemy + discord.py, deployable to
Railway as a single service.

## What it does

- **Key + HWID lock** — a key binds to one machine on first use. Anyone else
  who tries to redeem it is rejected. Keys are stored **hashed** (peppered
  HMAC-SHA256), never in plaintext.
- **Script gating** — the actual Lua never ships with the loader. The server
  returns it only to a request with a valid key + matching HWID. Responses are
  HMAC-signed so a client can verify they came from your server.
- **Two tiers out of the box** — `public` (free, keyless) and `premium`
  (key + HWID locked). Rename/add tiers in `app/config.py`.
- **Discord bot** — `/panel` posts buttons ("Get Script Public / Premium"),
  `/key` redeems a key and hands back a personal loader, plus admin commands to
  generate/revoke keys and reset HWIDs.
- **Rate limiting** on the public endpoint.

## Flow

```
admin  ──/genkey premium──────►  key handed to user
user   ── panel "Redeem Key" ─►  types key in popup, gets loadstring back
         (or /key <key>)          (bot links key to their Discord user)
user   ── runs loader ────────►  loader POSTs key + HWID to /api/script
server ── binds HWID ─────────►  returns premium.lua  → loadstring runs it
other machine, same key ──────►  403 "key already locked to another machine"
```

The panel has two buttons: **🌐 Get Script (Public)** hands the free loader to
anyone; **🔑 Redeem Key (Premium)** opens a popup where the user types their key
and gets the loadstring with the key already baked in.

## Deploy on Railway

1. Push this repo to GitHub, create a Railway project from it.
2. Add the **Postgres** plugin (recommended) — Railway injects `DATABASE_URL`
   and your keys/HWIDs persist across redeploys.
   *(Or use SQLite: attach a Volume, set `SQLITE_PATH=/data/orbit.db`.)*
3. Set the variables from `.env.example` (at minimum: `DISCORD_TOKEN`,
   `BASE_URL`, and new random values for `KEY_PEPPER`, `LOADER_SECRET`,
   `ADMIN_TOKEN`).
4. Deploy. Start command is already set in `railway.toml`:
   `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

The FastAPI server and the Discord bot run together in this one service.

## Discord bot setup

1. Create an application + bot at <https://discord.com/developers/applications>.
2. Copy the bot token → `DISCORD_TOKEN`.
3. Invite it with the `applications.commands` and `bot` scopes.
4. Set `DISCORD_GUILD_ID` to your server ID for instant command sync.
5. In a channel, run `/panel` (needs Administrator, or set `ADMIN_ROLE_ID`).

### Commands

| Command | Who | What |
|---|---|---|
| `/panel` | admin | Post the script panel with buttons |
| `/key <key>` | everyone | Redeem a key, get your loader |
| `/genkey <tier> <amount> [expires_days]` | admin | Generate keys |
| `/revoke <key>` | admin | Kill a key |
| `/resethwid <key>` | admin | Unbind a key's HWID |
| `/keyinfo <key>` | admin | Inspect a key |

## Your scripts

Drop your Lua into `scripts/public.lua` and `scripts/premium.lua`. Whatever is
in those files is what the server serves for that tier. Add more tiers by
adding `scripts/<tier>.lua` and listing the tier in `TIER_ORDER`
(`app/config.py`). Want the panel button labels changed? Edit `bot/client.py`
(`PanelView`).

## HTTP API

- `POST /api/script` — `{ "key": "...", "hwid": "...", "tier": "premium" }`
  → `{ ok, script, tier, sig, ts }` or `403`.
- `POST /admin/keys` — `Authorization: Bearer <ADMIN_TOKEN>`, body
  `{ tier, amount, expires_days?, note? }`.
- `POST /admin/revoke?key=...`, `POST /admin/reset-hwid?key=...`,
  `GET /admin/stats` — all Bearer-protected.

## Local dev

```bash
pip install -r requirements.txt
cp .env.example .env   # fill in values
uvicorn app.main:app --reload
```

## Notes

- The HWID comes from the executor (`gethwid()`), which varies per executor —
  the loader falls back to the Roblox client id if `gethwid` is missing.
- The in-memory rate limiter is per-process; for multiple replicas move it to
  Redis.
- `legacy/` holds the original Node WebSocket telemetry server, kept for
  reference; it is not part of this deployment.
