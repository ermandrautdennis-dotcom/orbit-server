# API reference

Base URL: `https://<your-domain>`. Everything below `/api` answers JSON except the
two endpoints that return Lua as `text/plain`.

There are **three** client classes and each has its own credential:

| Client | Credential | Reaches |
| --- | --- | --- |
| Discord bot, acting for a user | `X-Bot-Secret` + `X-Discord-User` | `/api/auth/*`, `/api/bot/*` |
| Discord bot, acting as operator | `X-Admin-Secret` + `X-Admin-Actor` | `/api/admin/*` |
| Lua loader | a per-license script key in the body | `/api/script/*` |
| anyone | none | `/health`, `/api/status`, `GET /api/script/loader` |

The two bot secrets are deliberately different. `BOT_API_SECRET` cannot generate a
key, blacklist anyone or touch the online switch — so the surface the panel buttons
drive carries far less authority than the admin surface, and escalating from one to
the other needs a second secret the user surface never sees.

## Conventions

Every response carries `ok`. Failures look like:

```json
{ "ok": false, "error": "invalid_request", "message": "Invalid request.", "request_id": "k3Jd9xQp12Ab" }
```

`request_id` also comes back in the `X-Request-Id` header and appears on every log
line for that request. Quote it in a bug report; it is the only way to connect a
user's complaint to the internal detail, which never leaves the server.

Error codes: `invalid_request` (400), `unauthorized` (401), `forbidden` (403),
`not_found` (404), `conflict` / `session_required` (409), `payload_too_large` (413),
`rate_limited` (429), `script_offline` (503), `internal_error` (500).

Every response carries `RateLimit-Limit`, `RateLimit-Remaining` and
`RateLimit-Reset`; a 429 adds `Retry-After`. Bodies are capped at 32 KB (4 MB for
the one source-upload endpoint).

---

## Public

### `GET /health`

Railway's healthcheck. 200 only when the database answers.

```json
{ "status": "ok" }
```

### `GET /api/status`

```json
{
  "ok": true,
  "script_status": "online",
  "scripts": [
    { "slug": "public",  "name": "Public Script", "version": "a1b2c3d4e5f6", "status": "online" },
    { "slug": "private", "name": "Private Hub",   "version": "9f8e7d6c5b4a", "status": "offline" }
  ]
}
```

`status` per script is the *effective* status — the global switch is already folded
in, so a client never has to combine the two and get it wrong.

Limit: 120 / minute / IP.

---

## Loader protocol

### `GET /api/script/loader`

Returns `lua/loader.lua` as `text/plain`, with the API base URL substituted. Public
by design and carries no secret.

Limit: 30 / minute / IP.

### `POST /api/script/authenticate`

Exchange a script key for a short-lived grant.

```json
{ "script_key": "osk_…", "tier": "public", "loader_version": "1.0.0" }
```

```json
{ "ok": true, "grant": "…", "expires_in": 45, "script": { "slug": "public", "version": "a1b2c3d4e5f6" } }
```

Checks, in order: the global and per-script switch (503 `script_offline`), the
script key and its license — existence, status, expiry, the owner's blacklist state
(401) — then the tier and, for `private`, the whitelist (403). A `public` license
asking for `private` is logged as `tier_escalation` at alert severity.

Limit: 12 / minute / IP.

### `POST /api/script/fetch`

```json
{ "grant": "…" }
```

Returns the Lua source as `text/plain` with `X-Script-Version`. The grant is
consumed atomically, so a replay loses the race and gets 401. The grant is bound to
the hashed IP it was issued to, and both switches are re-checked here — a
`/scriptoffline` between the two steps wins.

Responses from this endpoint are never compressed.

Limit: 12 / minute / IP.

---

## User surface (Discord bot)

Mounted at both `/api/auth` and `/api/bot`; identical handlers. Required headers:

```
X-Bot-Secret: <BOT_API_SECRET>
X-Discord-User: <snowflake>
X-Discord-Username: <base64url display name>   # optional, cosmetic
```

### `GET /me`

```json
{
  "ok": true,
  "user": { "discord_id": "…", "username": "…", "whitelisted": false, "created_at": "…" },
  "licenses": [{ "key_prefix": "A1B2", "tier": "public", "status": "active",
                 "activated_at": "…", "expires_at": "…", "last_used_at": "…", "usage_count": 3 }],
  "entitlements": { "public": true, "private": false }
}
```

`entitlements` is the one authorisation decision in the system, recomputed from live
rows. Every protected endpoint recomputes it; the bot only renders it.

### `POST /redeem`

```json
{ "key": "XXXX-XXXX-XXXX-XXXX" }
```

Activates the key, binds it to the Discord account, and establishes a session.
Idempotent for the owner (`already_redeemed: true`).

**Every failure answers `400 invalid_request` with the message `Invalid request.`** —
a key that does not exist, one that is revoked, one that expired and one that
belongs to someone else are indistinguishable from outside. The real reason goes to
`audit_logs` only. While the script is globally offline this answers 503 without
consuming the key.

Limit: 8 / 10 minutes, per IP *and* per Discord user.

### `POST /session`

Establishes or extends the caller's session; requires an active license. Returns
`{ ok, created, expires_at, entitlements }`. No token: the bot proves identity with
its own credential, and a bearer token nobody needs is only something to steal.

### `POST /validate`

`{ "tier": "private" }` (optional) → `{ ok, valid, entitlements }`.

### `POST /script`

```json
{ "tier": "public" }
```

```json
{
  "ok": true, "tier": "public", "name": "Public Script", "version": "a1b2c3d4e5f6",
  "status": "online", "rotated": false,
  "script_key": "osk_…",
  "loader_snippet": "script_key = \"osk_…\"\nscript_tier = \"public\"\nloadstring(game:HttpGet(\"https://…/api/script/loader\"))()",
  "loader_url": "https://…/api/script/loader"
}
```

Mints a fresh script key and returns it **once** — it is stored as a keyed hash and
no endpoint can read it back. Calling this again rotates the key and invalidates the
previous loader (`rotated: true`). Requires a live session; without one it answers
`409 session_required`, which the bot resolves by calling `/session` and retrying
once.

Never returns the protected source.

Limit: 10 / 10 minutes / IP, 6 / 10 minutes / user.

---

## Admin surface

Required headers:

```
X-Admin-Secret: <ADMIN_API_SECRET>
X-Admin-Actor: <operator's Discord snowflake>   # audit attribution
```

A wrong or absent secret answers `403 forbidden` with `Access denied.` and nothing
else, and is logged at alert severity. Base limit: 20 / minute.

| Route | Body | Notes |
| --- | --- | --- |
| `POST /api/admin/keys/generate` | `{ tier?, ttl_days?, note? }` | 201, returns the plaintext key once |
| `POST /api/admin/keys/generate-mass` | `{ count, tier?, ttl_days?, note? }` | capped by `MAX_MASS_KEYS`; 5 / hour |
| `POST /api/admin/keys/revoke` | `{ license_id, reason? }` | also burns the script key and any in-flight grant |
| `GET /api/admin/keys/stats` | — | counts by status and tier |
| `POST /api/admin/users/whitelist` | `{ discord_id, reason? }` | creates the user row if absent |
| `POST /api/admin/users/unwhitelist` | `{ discord_id, reason? }` | |
| `POST /api/admin/users/blacklist` | `{ discord_id, reason? }` | revokes licenses, script keys, grants and sessions in one transaction; refuses `DISCORD_OWNER_IDS` |
| `POST /api/admin/users/unblacklist` | `{ discord_id, reason? }` | licenses stay revoked — issue a new key |
| `GET /api/admin/users/:discordId` | — | state and licenses |
| `POST /api/admin/script/offline` | `{ slug?, reason? }` | no `slug` = global kill switch, burns every outstanding grant |
| `POST /api/admin/script/online` | `{ slug?, reason? }` | |
| `GET /api/admin/script/status` | — | per-script and effective status |
| `POST /api/admin/script/source` | `{ slug, source }` | ≤ 2 MB; version becomes a content hash; 20 / hour |
| `GET /api/admin/audit` | `?limit=&action=&discord_id=` | newest first, limit clamped to 200 |

`ttl_days: 0` means no expiry. Unknown body fields are rejected, not ignored, so
mass assignment is impossible.

---

## Audit actions

`auth.login` · `auth.login_denied` · `auth.logout` · `auth.session_invalid` ·
`key.generated` · `key.generated_mass` · `key.redeem_ok` · `key.redeem_fail` ·
`key.revoked` · `script.key_minted` · `script.source_updated` ·
`loader.auth_ok` · `loader.auth_fail` · `script.download` ·
`script.download_denied` · `script.online` · `script.offline` ·
`user.whitelisted` · `user.unwhitelisted` · `user.blacklisted` ·
`user.unblacklisted` · `admin.auth_fail` · `bot.auth_fail` ·
`security.rate_limited` · `security.suspicious`

Severity is `info`, `warn` or `alert`. Rows hold a hashed IP, never a raw address,
and never a full license key, script key or grant token.
