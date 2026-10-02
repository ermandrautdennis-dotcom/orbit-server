# Tests

```bash
# one-off local Postgres
docker compose up -d postgres

# or point at any scratch database
export TEST_DATABASE_URL=postgresql://user:pass@127.0.0.1:5432/orbit_test

npm test              # unit + integration
npm run test:unit     # no database required
npm run test:integration
```

## Layout

| file | what it covers |
| --- | --- |
| `unit/crypto.test.js` | key format, entropy, uniform symbol distribution, normalisation, domain-separated hashing, constant-time compare, Argon2id/scrypt |
| `unit/redaction.test.js` | the logger cannot emit a credential, and does not over-redact the audit fields |
| `unit/entitlements.test.js` | the single authorisation decision, in isolation |
| `integration/auth.test.js` | admin vs user credential separation, generation, redemption, the "no key oracle" property, blacklist/whitelist, SQL-injection attempts |
| `integration/loader.test.js` | the full loader protocol, grant replay/expiry/IP binding, script-key rotation, tier escalation, the kill switch |
| `integration/abuse.test.js` | rate limits, error shaping, header hardening, no CORS, logging hygiene |
| `integration/bot.test.js` | Discord panel → bot handler → API → PostgreSQL, with stub interactions |
| `integration/schema.test.js` | migrations, checksums, indexes, database-level constraints |

## Why the integration tests run serially

Every integration file shares one database and truncates state between cases, so
`npm test` passes `--test-concurrency=1`. Running the files in parallel makes them
clear each other's rows. If you want parallelism, give each file its own database
via `TEST_DATABASE_URL` and run them as separate processes.

The suite starts the real Express app on an ephemeral port — not a mock — so the
middleware stack under test is the one that ships: rate limiting against real
Postgres counters, real validation, real error shaping.
