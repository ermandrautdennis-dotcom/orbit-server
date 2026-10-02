// Test bootstrap. Sets the environment before anything imports the config
// singleton, runs the migrations against a scratch database, and starts the real
// Express app on an ephemeral port so the integration tests exercise the actual
// middleware stack — rate limiting, validation, error shaping and all.
//
// Point TEST_DATABASE_URL at a throwaway database. Its tables are truncated
// between files, never dropped.
import { execFileSync } from 'node:child_process';

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = process.env.TEST_DATABASE_URL
    ?? 'postgresql://orbit:orbit_dev_only@127.0.0.1:5432/orbit_test';
process.env.DATABASE_SSL = 'false';
process.env.PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL ?? 'http://127.0.0.1:3000';
process.env.TRUST_PROXY = 'false';
process.env.DEFAULT_KEY_TTL_DAYS = '30';
process.env.MAX_MASS_KEYS = '25';
process.env.GRANT_TTL_SECONDS = '45';
process.env.REQUIRE_WHITELIST_FOR_PRIVATE = 'true';
process.env.LOG_LEVEL = 'error';

// Distinct, test-only secrets. The config module also substitutes deterministic
// test values, but being explicit keeps the two admin/bot credentials provably
// different, which several authorisation tests depend on.
process.env.KEY_PEPPER = 'dGVzdC1rZXktcGVwcGVyLTAxMjM0NTY3ODlhYmNkZWZnaGlqa2xtbm8';
process.env.TOKEN_PEPPER = 'dGVzdC10b2tlbi1wZXBwZXItMDEyMzQ1Njc4OWFiY2RlZmdoaWprbG0';
process.env.IP_HASH_PEPPER = 'dGVzdC1pcC1wZXBwZXItMDEyMzQ1Njc4OWFiY2RlZmdoaWprbG1ub3A';
process.env.ADMIN_API_SECRET = 'dGVzdC1hZG1pbi1zZWNyZXQtMDEyMzQ1Njc4OWFiY2RlZmdoaWprbA';
process.env.BOT_API_SECRET = 'dGVzdC1ib3Qtc2VjcmV0LTAxMjM0NTY3ODlhYmNkZWZnaGlqa2xtbm8';

export const ADMIN_SECRET = process.env.ADMIN_API_SECRET;
export const BOT_SECRET = process.env.BOT_API_SECRET;

const { createApp } = await import('../../backend/src/app.js');
const { query, closePool } = await import('../../backend/src/database/pool.js');

let server = null;
let baseUrl = null;
let migrated = false;

export async function startServer(port = 0) {
    if (!migrated) {
        // Run the real migration runner, so the tests also prove migrations apply
        // cleanly from nothing.
        execFileSync(process.execPath, ['database/migrate.js', 'up'], {
            stdio: 'pipe',
            env: { ...process.env },
        });
        migrated = true;
    }
    if (server) return baseUrl;
    const app = createApp();
    await new Promise((resolve) => { server = app.listen(port, '127.0.0.1', resolve); });
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    return baseUrl;
}

export async function stopServer() {
    if (server) await new Promise((r) => server.close(r));
    server = null;
    await closePool();
}

/** Clear all mutable state between test files. Keeps the two seeded scripts. */
export async function resetState() {
    await query('TRUNCATE script_grants, loader_credentials, sessions, license_keys, audit_logs, rate_limits, users RESTART IDENTITY CASCADE');
    await query("UPDATE settings SET value = '\"offline\"'::jsonb WHERE key = 'global_script_status'");
    await query("UPDATE scripts SET status = 'offline'");
}

export async function clearRateLimits() {
    await query('TRUNCATE rate_limits');
}

/** HTTP helper. Returns { status, headers, json, text }. */
export async function http(method, path, { body = null, headers = {} } = {}) {
    const res = await fetch(`${baseUrl}${path}`, {
        method,
        headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...headers },
        body: body === null ? undefined : (typeof body === 'string' ? body : JSON.stringify(body)),
    });
    const text = await res.text();
    let json = null;
    try { json = text ? JSON.parse(text) : null; } catch { /* text response */ }
    return { status: res.status, headers: res.headers, json, text };
}

export const asAdmin = (actor = '111111111111111111') => ({
    'x-admin-secret': ADMIN_SECRET,
    'x-admin-actor': actor,
});

export const asUser = (discordId, username = 'tester') => ({
    'x-bot-secret': BOT_SECRET,
    'x-discord-user': discordId,
    'x-discord-username': Buffer.from(username, 'utf8').toString('base64url'),
});

export { query };
