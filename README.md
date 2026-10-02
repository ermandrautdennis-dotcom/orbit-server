# Orbit — Lua script authentication & licensing

A licensing platform for hosted Lua scripts. Users never receive the raw file: the
script lives in Postgres behind an API, and the only way to it is a Lua loader that
authenticates first.

**There is no website.** The entire user-facing panel is a Discord embed produced by
`/genpanel` — buttons and a modal, driven by the bot, talking to the API.

```
Discord user
    ↓  presses a button on the /genpanel embed
Discord bot          (holds BOT_API_SECRET / ADMIN_API_SECRET)
    ↓  HTTPS
Railway API          (Express, no browser surface, no cookies, no CORS)
    ↓
PostgreSQL           (licenses, sessions, grants, audit log)
    ↓
authentication       (license → tier → whitelist → online switch)
    ↓
Lua loader           (short-lived single-use grant)
    ↓
protected Lua script
```

## Layout

```
backend/src
  config/env.js          fail-fast configuration; no usable default for any secret
  security/crypto.js     key generation, keyed hashing, Argon2id/scrypt
  database/pool.js       pg Pool; parameterised queries only
  middleware/            request context, rate limiting, validation, auth, errors
  routes/                status, user (bot-driven), script (loader), admin
  services/              users, licenses, sessions, grants, scripts, loader keys, audit
  app.js  server.js
bot
  commands/              10 slash commands, including /genpanel
  interactions/panel.js  the panel embed, its buttons and the redeem modal
  services/api.js        the two service credentials, kept apart
  utils/                 role authorisation, reply helpers
lua/loader.lua           client bootstrap; holds no secret of ours
database/
  migrations/            001 schema · 002 scripts · 003 script keys
  migrate.js             forward-only, checksummed, idempotent
tests/                   103 tests: unit + integration over a real Postgres
docs/API.md  docs/SECURITY.md
scripts/                 generate-secrets · seed-script · start-all
Dockerfile  docker-compose.yml  railway.json  railway.bot.json  .env.example
```

## How access works

1. An operator runs `/genkey` (or `/genmasskey`). The plaintext key is shown **once**,
   ephemerally, and is never stored — only `HMAC-SHA256(KEY_PEPPER, key)` is.
2. A user presses **Redeem Key** on the panel, types the key into the modal. The API
   activates it, binds it to their Discord id and opens a session.
3. They press **Get Script**. The API mints a *script key* (`osk_…`, shown once,
   rotatable) and returns the loader snippet.
4. Their executor runs the snippet. The loader posts the script key to
   `/api/script/authenticate`, gets a grant that lives 45 seconds, is single-use and
   IP-bound, then exchanges it at `/api/script/fetch` for the source.
5. `/scriptoffline` stops step 4 for everyone within one request, including people
   holding valid keys and grants already in flight.

Full endpoint reference: [`docs/API.md`](docs/API.md).
Threat model and hashing rationale: [`docs/SECURITY.md`](docs/SECURITY.md).

---

# Deployment

## 1. Create the Railway project

```bash
npm i -g @railway/cli
railway login
railway init            # or: New Project in the dashboard
```

Push this repository to GitHub and connect it, or deploy with `railway up`.

## 2. Add PostgreSQL

Dashboard → **New** → **Database** → **Add PostgreSQL**.

Railway injects `DATABASE_URL` into services in the same project. Nothing to
configure: `backend/src/config/env.js` reads it directly. Leave `DATABASE_SSL=false`
— the internal network is already private. Set it to `true` only if you point at a
Postgres reachable over the public internet.

## 3. Generate and set the environment variables

```bash
npm install
npm run secrets         # prints five fresh 32-byte secrets
```

Set these on the **API** service (Variables tab, or `railway variables --set`):

```
NODE_ENV=production
PUBLIC_BASE_URL=https://your-api.up.railway.app
TRUST_PROXY=true
KEY_PEPPER=…
TOKEN_PEPPER=…
IP_HASH_PEPPER=…
ADMIN_API_SECRET=…
BOT_API_SECRET=…
DISCORD_CLIENT_ID=…
DEFAULT_KEY_TTL_DAYS=30
MAX_MASS_KEYS=100
REQUIRE_WHITELIST_FOR_PRIVATE=true
```

`PORT` and `DATABASE_URL` come from Railway. See `.env.example` for every variable
with its meaning.

Two things the API refuses to boot without in production, on purpose: an `https://`
`PUBLIC_BASE_URL`, and `TRUST_PROXY=true`. Railway always proxies, and without that
flag every request looks like it came from the proxy — which silently collapses all
per-IP rate limits and all audit IP hashes onto one value.

## 4. Deploy the backend

The `Dockerfile` runs migrations then starts the API:

```
node database/migrate.js up && node backend/src/server.js
```

`railway.json` already sets the build, that start command, `/health` as the
healthcheck and a restart policy. Deploy, then:

```bash
curl https://your-api.up.railway.app/health     # {"status":"ok"}
curl https://your-api.up.railway.app/api/status # script_status: "offline"
```

Offline is correct — nothing is served until you say so in step 9.

Generate a public domain under Settings → Networking → **Generate Domain**, and set
`PUBLIC_BASE_URL` to it. Railway terminates TLS for you; a custom domain works the
same way once its CNAME resolves.

## 5. Create the Discord bot

1. <https://discord.com/developers/applications> → **New Application**.
2. **Bot** → **Reset Token** → copy it. This is `DISCORD_BOT_TOKEN`.
3. Leave every privileged intent **off**. The bot needs none of them.
4. **General Information** → copy the Application ID. This is `DISCORD_CLIENT_ID`.
5. **OAuth2 → URL Generator**: scopes `bot` + `applications.commands`, bot
   permissions **Send Messages** and **Embed Links**. Open the generated URL and
   invite it to your server.
6. In Discord, enable Developer Mode (Settings → Advanced) and copy:
   * your server's id → `DISCORD_GUILD_ID`
   * your staff role's id → `DISCORD_ADMIN_ROLE_IDS` (comma-separate for several)
   * your own user id → `DISCORD_OWNER_IDS` (break-glass; survives role changes)

## 6. Deploy the bot

Run it as a **second Railway service** from the same repository. Point its config
path at `railway.bot.json`, or just override the start command:

```
node bot/register-commands.js && node bot/index.js
```

Variables for the bot service:

```
NODE_ENV=production
DISCORD_BOT_TOKEN=…
DISCORD_CLIENT_ID=…
DISCORD_GUILD_ID=…
DISCORD_ADMIN_ROLE_IDS=…
DISCORD_OWNER_IDS=…
ADMIN_API_SECRET=…            # identical to the API service
BOT_API_SECRET=…              # identical to the API service
API_BASE_URL=http://api.railway.internal:3000
PUBLIC_BASE_URL=https://your-api.up.railway.app
```

`API_BASE_URL` should be the API's **private** URL so bot traffic never leaves the
project. `PUBLIC_BASE_URL` is what goes in the loader snippet users copy, so that one
must be the public HTTPS domain. The bot service needs no `DATABASE_URL` — it talks
only to the API.

Two services is the better default: they scale and fail independently, and only the
bot holds the Discord token. To run both in one container instead, use
`npm run start:all`.

The bot refuses to start if neither `DISCORD_ADMIN_ROLE_IDS` nor `DISCORD_OWNER_IDS`
is set, since nobody could then run any command.

## 7. Run the database migrations

The Dockerfile runs them at boot, so a normal deploy needs nothing. To run them by
hand:

```bash
railway run npm run migrate          # apply
railway run npm run migrate:status   # list applied / pending
```

Migrations are forward-only, idempotent, and recorded with a SHA-256. Editing a
migration that has already been applied is refused — add a new file instead. Safe to
run on every boot and from several replicas at once.

## 8. Upload your script

```bash
railway run node scripts/seed-script.js public  ./my-script.lua
railway run node scripts/seed-script.js private ./my-hub.lua
```

Or over the API:

```bash
curl -X POST https://your-api.up.railway.app/api/admin/script/source \
  -H "x-admin-secret: $ADMIN_API_SECRET" \
  -H "x-admin-actor: <your-discord-id>" \
  -H 'content-type: application/json' \
  -d "{\"slug\":\"public\",\"source\":$(jq -Rs . < my-script.lua)}"
```

The stored version is a content hash, so you cannot forget to bump a version number.

## 9. Post the panel and go live

In Discord:

```
/genpanel                 # posts the panel; pin it
/scriptonline             # start serving
/scriptstatus             # confirm
/genkey tier:public days:30
```

The panel is stateless — its buttons keep working across restarts and redeploys, so
one per server is enough.

## 10. Test the whole path

```bash
curl https://your-api.up.railway.app/api/status     # script_status: "online"
```

Then, as a normal user: **Redeem Key** → paste the key from `/genkey` → **Get
Script** → copy the snippet into your executor. You should see
`[orbit] authenticated` followed by `[orbit] loaded`.

Now verify the kill switch, which is the part worth testing properly: run
`/scriptoffline` and re-run the snippet. It must print
`Script is currently offline.` even though the key is still valid. `/scriptonline`
brings it back.

---

# Local development

```bash
cp .env.example .env
npm run secrets >> .env       # then delete the blank placeholder lines
docker compose up -d postgres
npm install
npm run migrate
npm start                     # API on :3000
npm run bot:register          # once, after changing commands
npm run start:bot
```

Or bring everything up at once with `docker compose up --build`.

```bash
npm test                      # 103 tests
npm run test:unit             # no database needed
```

See [`tests/README.md`](tests/README.md) for what each suite covers and why the
integration tests run serially.

---

# Commands

| Command | Who | Does |
| --- | --- | --- |
| `/genpanel` | admin | posts the authentication panel |
| `/genkey` | admin | one license key, shown once, ephemerally |
| `/genmasskey` | admin | up to `MAX_MASS_KEYS` keys, as an ephemeral file |
| `/revokekey` | admin | revokes a license by id; burns its script key and grants |
| `/whitelist` | admin | whitelist a user (required for the private hub); `remove:true` to undo |
| `/blacklist` | admin | revokes licenses, script keys, grants and sessions at once |
| `/userinfo` | admin | a user's licenses and whitelist/blacklist state |
| `/scriptoffline` | admin | kill switch, global or one tier |
| `/scriptonline` | admin | re-enable |
| `/scriptstatus` | admin | online/offline plus license counts |

Every admin command checks `DISCORD_ADMIN_ROLE_IDS` / `DISCORD_OWNER_IDS`, replies
ephemerally, and writes to `audit_logs` with the acting operator. The backend does
not rely on that check — it accepts only `ADMIN_API_SECRET` — so a Discord-side
bypass still cannot forge an admin call.

---

# Operating notes

* **Both scripts start offline.** Deploying does not expose anything.
* **A plaintext license key exists exactly once**, in the ephemeral `/genkey` reply.
  Nothing can recover it afterwards; reissue instead.
* **A script key is shown once** and rotates on each **Get Script**, which
  invalidates the previous loader. That is the lever for a leaked key.
* **Unblacklisting does not restore licenses.** The blacklist revoked them; issue a
  new key.
* **Watch the alerts:** `GET /api/admin/audit?action=security.suspicious` and
  `admin.auth_fail`. The first means a license is being shared, the second means
  someone is probing the admin surface.

# Honest limits

This makes unauthorised access expensive and revocation immediate. It does not stop
someone who legitimately authenticates from keeping the source they received —
nothing that ships code to a client can, and the design spends its effort on access
control, attribution and revocation instead of pretending otherwise. If the database
itself is stolen, the attacker reads your Lua but cannot derive a single license key,
script key or session token without the peppers, which live only in the environment.
`docs/SECURITY.md` sets out the whole picture, including what it deliberately does
not do.
