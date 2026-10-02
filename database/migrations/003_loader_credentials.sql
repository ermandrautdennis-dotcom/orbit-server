-- 003_loader_credentials.sql
--
-- The plaintext license key is shown exactly once and is not recoverable from
-- the database, so the panel cannot paste it back into a loader snippet later.
-- Instead each active license mints a separate, rotatable *script key*: a
-- 256-bit opaque credential that is what actually travels in the Lua loader.
--
-- This is strictly better than shipping the license key to the client:
--   * it can be rotated without reissuing the license,
--   * it is revoked independently when a leak is suspected,
--   * compromising it never reveals the license key.

CREATE TABLE IF NOT EXISTS loader_credentials (
    id           BIGSERIAL PRIMARY KEY,
    license_id   BIGINT      NOT NULL REFERENCES license_keys (id) ON DELETE CASCADE,
    token_hash   BYTEA       NOT NULL UNIQUE,
    token_prefix TEXT        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ,
    revoked_at   TIMESTAMPTZ,
    usage_count  BIGINT      NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS loader_credentials_license_idx ON loader_credentials (license_id);
-- At most one live script key per license.
CREATE UNIQUE INDEX IF NOT EXISTS loader_credentials_active_uidx
    ON loader_credentials (license_id) WHERE revoked_at IS NULL;
