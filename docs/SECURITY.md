# Security notes

## What this system can and cannot do

It can make unauthorised *access* expensive and revocation immediate. It cannot
stop someone who legitimately authenticates from keeping what they received —
nothing that ships code to a client can, and any product claiming otherwise is
lying. The design therefore spends its effort on access control, attribution and
revocation, which are the levers that actually work:

* every download is attributed to a license and a hashed IP in `audit_logs`;
* `/scriptoffline` stops all delivery within one request, including for users
  holding valid keys and grants already in flight;
* `/blacklist` burns an account's licenses, script keys, grants and sessions in a
  single transaction;
* a leaked script key is rotated from the panel without reissuing the license.

No part of this document claims the system is uncrackable. It is defence in depth.

## Where decisions are made

Every authorisation decision is server-side, recomputed from live database rows on
every request. Specifically:

| Decision | Where | Not trusted |
| --- | --- | --- |
| who is asking | the signed Discord interaction, relayed by the bot | any id in a request body, any component `custom_id` |
| what they may have | `entitlementsFor()` over live license rows | anything the client sends, including the tier a button claims |
| is the script servable | `scripts.servable()` — global switch AND per-script row | the loader's own checks, which are cosmetic |
| is this grant usable | one atomic `UPDATE … WHERE consumed_at IS NULL` | the grant's own contents |
| is this an operator | `ADMIN_API_SECRET` only | Discord roles, which are the *first* gate, never the only one |

The Lua loader makes no security decision. Patching it out gains nothing: the
server re-checks the license, the tier, the whitelist, the blacklist and both
switches before it emits a byte of source.

## Credential separation

Five secrets, each with one job, all required to be distinct in production:

| Secret | Purpose | Rotating it |
| --- | --- | --- |
| `KEY_PEPPER` | HMAC key for license-key lookup hashes | **invalidates every license key.** Back it up. |
| `TOKEN_PEPPER` | HMAC key for session and script-key hashes | signs everyone out and burns every script key |
| `IP_HASH_PEPPER` | pseudonymises IPs in logs | old and new hashes stop correlating |
| `ADMIN_API_SECRET` | the operator surface | update the API and bot services together |
| `BOT_API_SECRET` | the user surface the panel drives | update both services together |

The last two being separate is the point: a bug in a panel button handler cannot
reach `/api/admin/*`, because that path accepts a credential the user surface never
holds. There is no role bit on `users` that grants admin, so privilege escalation is
not a matter of a missed check — it is structurally unreachable.

## Hashing choices, and why they differ

* **License keys** — 80 bits of CSPRNG entropy, drawn with rejection sampling so
  the symbol distribution is exactly uniform (a plain `byte % 32` would bias the
  low symbols). Stored as `HMAC-SHA256(KEY_PEPPER, key)`.

  A salted password hash is the wrong tool here and using one would be worse, not
  better: lookup by value would require scanning and verifying every row. Against a
  high-entropy secret there is no dictionary to attack, and an attacker holding the
  database still cannot derive a key without the pepper. That is the same reasoning
  that makes a keyed hash correct for API tokens generally.
* **Session tokens, script keys, grants** — 256 bits of CSPRNG, stored as
  `HMAC-SHA256(TOKEN_PEPPER, …)` with a domain prefix per kind, so a value cannot
  be replayed across kinds.
* **Operator-chosen secrets** — `hashSecret()` uses Argon2id when the optional
  native module is present and scrypt (N=2^15, memory-hard) when it is not. Both
  are strong; the fallback keeps `npm install` working on hosts without a
  toolchain. No such secret ships by default.

## The threats this was built against

| Threat | Control |
| --- | --- |
| SQL injection | every query parameterised; no string-interpolated SQL anywhere; zod-validated and *stripped* inputs; `CHECK` constraints at the database level too |
| Authentication bypass | identity comes from a Discord-signed interaction relayed under a service secret; no client-held bearer token exists to forge |
| Authorisation bypass / privilege escalation | user and admin surfaces take different secrets; no shared handler; no admin flag on `users` |
| IDOR | a key already bound to another account is refused and the attempt is an alert; `/me` only ever reads the asserting user's own rows |
| Token theft | grants live 45 s, are single-use and IP-bound; script keys are rotatable; sessions are revocable in bulk |
| Replay | grant consumption is one atomic `UPDATE`; the loser of the race gets 401 |
| Brute force / key guessing | 80-bit keys; redeem capped at 8 per 10 minutes per IP *and* per user; violations audited |
| Key enumeration | every redeem failure returns an identical status, code and message — tested for, not just intended |
| Rate-limit bypass | counters live in Postgres, so they hold across replicas and restarts; buckets key off hashed IP and authenticated subject, never a client-supplied header; `X-Forwarded-For` is ignored unless `TRUST_PROXY` is on, and then only one hop |
| Mass key abuse | `MAX_MASS_KEYS` cap, 5 generations/hour, bulk issuance logged at `warn` with every prefix |
| Discord command abuse | role/owner allowlist, 2 s per-user cooldown, `ManageGuild` default permission, every attempt logged authorised or not |
| Information leakage | one generic message per failure class; no stack trace, SQL fragment or upstream error ever crosses the HTTP boundary; the logger redacts credential-shaped fields before serialising |
| Session abuse | sessions are a real gate on `/script`; a revoked session forces re-authentication without touching the license |
| License sharing | more than `MAX_SESSIONS_PER_LICENSE` distinct source addresses in ten minutes raises a `security.suspicious` alert — logged, not enforced, so a mobile user is not locked out by a heuristic |
| XSS / CSRF | no HTML is rendered and no cookie is issued, so neither surface exists. CSP is `default-src 'none'`, and no CORS header is emitted to any origin |
| Debug endpoints | none exist; a test asserts it |

## Logging

Logged: every authentication attempt and its outcome, redemptions, revocations,
downloads, whitelist/blacklist events, every admin action with its actor, rate-limit
violations and suspicious patterns.

Never logged: plaintext license keys, script keys, grant tokens, session tokens,
peppers, the admin or bot secret, the database URL, or raw IP addresses. The logger
redacts by key name before serialising, and `audit_logs` rows are redacted again on
the way in. A test asserts that a full lifecycle leaves none of those values in the
database or on stdout.

Kept deliberately: `key_prefix` (the first group of a key) and `key_hash`, which are
not secret and without which the audit trail is useless.

## Operational notes

* `PUBLIC_BASE_URL` must be `https://` in production; boot fails otherwise, and
  plain HTTP is 308-redirected.
* `TRUST_PROXY` must be `true` behind Railway or any ingress. Boot fails in
  production if it is not, because otherwise every request appears to come from the
  proxy and all per-IP limits and audit hashes collapse onto one value.
* Secrets are validated at boot for length; a short passphrase is refused.
* Both scripts start **offline**. Nothing is served until an operator runs
  `/scriptonline`.
* The container runs as a non-root user and writes nothing to disk.
* Give the Postgres role only what it needs. The app requires `SELECT`, `INSERT`,
  `UPDATE`, `DELETE` and sequence usage on its own schema; it never needs
  `SUPERUSER`, and after migrations it needs no DDL.
* Rotating `KEY_PEPPER` is a destructive operation. Treat it as a break-glass
  response to a database compromise, and tell your users first.

## If the database is stolen

The attacker gets: license key hashes, script key hashes, session hashes, hashed
IPs, and **the plaintext Lua source** in `scripts.source`.

They cannot derive a license key, script key or session token without the peppers,
which live only in the environment. They can read your script — so if that matters
more than operational convenience, keep the source encrypted at rest under a key
held outside the database and decrypt it in `sourceBySlug()`. That is a deliberate
trade this build does not make, because a key held in the same process that serves
the source buys less than it appears to.
