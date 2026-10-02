-- 001_init.sql — core schema for the Orbit auth/licensing platform.
-- Every identifier that reaches this schema from the outside arrives through a
-- parameterised query; nothing in the application concatenates SQL.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Users ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL PRIMARY KEY,
    discord_id    TEXT        NOT NULL UNIQUE,
    username      TEXT        NOT NULL DEFAULT 'unknown',
    blacklisted   BOOLEAN     NOT NULL DEFAULT FALSE,
    whitelisted   BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS users_blacklisted_idx  ON users (blacklisted) WHERE blacklisted;
CREATE INDEX IF NOT EXISTS users_whitelisted_idx  ON users (whitelisted) WHERE whitelisted;

-- ── Scripts ──────────────────────────────────────────────────────────────────
-- status: 'online' | 'offline'
-- tier flags mirror the two products the panel exposes.
CREATE TABLE IF NOT EXISTS scripts (
    id             BIGSERIAL PRIMARY KEY,
    slug           TEXT        NOT NULL UNIQUE,
    name           TEXT        NOT NULL,
    version        TEXT        NOT NULL DEFAULT '0.0.0',
    status         TEXT        NOT NULL DEFAULT 'offline'
                   CHECK (status IN ('online', 'offline')),
    public_script  BOOLEAN     NOT NULL DEFAULT FALSE,
    private_script BOOLEAN     NOT NULL DEFAULT FALSE,
    source         TEXT        NOT NULL DEFAULT '-- empty script\n',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT scripts_tier_chk CHECK (public_script OR private_script)
);
CREATE INDEX IF NOT EXISTS scripts_status_idx ON scripts (status);

-- ── License keys ─────────────────────────────────────────────────────────────
-- key_hash is HMAC-SHA256(KEY_PEPPER, normalised key). The plaintext key is
-- shown exactly once, at generation time, and never persisted.
-- status: 'unused' | 'active' | 'revoked' | 'expired'
-- tier:   'public' | 'private'
CREATE TABLE IF NOT EXISTS license_keys (
    id               BIGSERIAL PRIMARY KEY,
    key_hash         BYTEA       NOT NULL UNIQUE,
    key_prefix       TEXT        NOT NULL,
    status           TEXT        NOT NULL DEFAULT 'unused'
                     CHECK (status IN ('unused', 'active', 'revoked', 'expired')),
    tier             TEXT        NOT NULL DEFAULT 'public'
                     CHECK (tier IN ('public', 'private')),
    discord_user_id  TEXT        REFERENCES users (discord_id) ON DELETE SET NULL,
    created_by       TEXT,
    note             TEXT,
    revoked_reason   TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    activated_at     TIMESTAMPTZ,
    expires_at       TIMESTAMPTZ,
    last_used_at     TIMESTAMPTZ,
    usage_count      BIGINT      NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS license_keys_owner_idx   ON license_keys (discord_user_id);
CREATE INDEX IF NOT EXISTS license_keys_status_idx  ON license_keys (status);
CREATE INDEX IF NOT EXISTS license_keys_prefix_idx  ON license_keys (key_prefix);
CREATE INDEX IF NOT EXISTS license_keys_expiry_idx  ON license_keys (expires_at)
    WHERE expires_at IS NOT NULL;

-- ── Panel sessions ───────────────────────────────────────────────────────────
-- token_hash is HMAC-SHA256(TOKEN_PEPPER, token). Raw tokens live only in the
-- client cookie.
CREATE TABLE IF NOT EXISTS sessions (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash      BYTEA       NOT NULL UNIQUE,
    ip_hash         TEXT,
    user_agent_hash TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    last_used_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS sessions_user_idx    ON sessions (user_id);
CREATE INDEX IF NOT EXISTS sessions_expiry_idx  ON sessions (expires_at);

-- ── Loader grants (short-lived, single-use) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS script_grants (
    id           BIGSERIAL PRIMARY KEY,
    license_id   BIGINT      NOT NULL REFERENCES license_keys (id) ON DELETE CASCADE,
    script_id    BIGINT      NOT NULL REFERENCES scripts (id) ON DELETE CASCADE,
    token_hash   BYTEA       NOT NULL UNIQUE,
    ip_hash      TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at   TIMESTAMPTZ NOT NULL,
    consumed_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS script_grants_license_idx ON script_grants (license_id);
CREATE INDEX IF NOT EXISTS script_grants_expiry_idx  ON script_grants (expires_at);

-- ── Audit log ────────────────────────────────────────────────────────────────
-- metadata never contains plaintext keys, tokens or secrets; writers redact.
CREATE TABLE IF NOT EXISTS audit_logs (
    id              BIGSERIAL PRIMARY KEY,
    action          TEXT        NOT NULL,
    severity        TEXT        NOT NULL DEFAULT 'info'
                    CHECK (severity IN ('info', 'warn', 'alert')),
    discord_user_id TEXT,
    ip_hash         TEXT,
    request_id      TEXT,
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata        JSONB       NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS audit_logs_action_idx ON audit_logs (action, timestamp DESC);
CREATE INDEX IF NOT EXISTS audit_logs_actor_idx  ON audit_logs (discord_user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS audit_logs_time_idx   ON audit_logs (timestamp DESC);
CREATE INDEX IF NOT EXISTS audit_logs_sev_idx    ON audit_logs (severity, timestamp DESC)
    WHERE severity <> 'info';

-- ── Distributed rate limit counters ──────────────────────────────────────────
-- Fixed-window counters shared by every API instance. A single atomic UPSERT
-- per request keeps this cheap and makes limits survive horizontal scaling,
-- which an in-memory limiter cannot.
CREATE TABLE IF NOT EXISTS rate_limits (
    bucket       TEXT        NOT NULL,
    window_start TIMESTAMPTZ NOT NULL,
    hits         INTEGER     NOT NULL DEFAULT 0,
    PRIMARY KEY (bucket, window_start)
);
CREATE INDEX IF NOT EXISTS rate_limits_window_idx ON rate_limits (window_start);

-- ── Global settings (key/value) ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS settings (
    key        TEXT        PRIMARY KEY,
    value      JSONB       NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by TEXT
);

INSERT INTO settings (key, value)
VALUES ('global_script_status', '"offline"'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ── updated_at maintenance ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_touch   ON users;
CREATE TRIGGER users_touch   BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS scripts_touch ON scripts;
CREATE TRIGGER scripts_touch BEFORE UPDATE ON scripts
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
