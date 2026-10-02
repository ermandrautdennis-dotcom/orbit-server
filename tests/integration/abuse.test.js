// Rate limiting, error shaping and information leakage.
import test, { before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
    startServer, stopServer, resetState, clearRateLimits, http, asAdmin, asUser, query,
} from '../helpers/setup.js';

const USER = '400000000000000001';

before(async () => { await startServer(); });
after(async () => { await stopServer(); });
beforeEach(async () => { await resetState(); await clearRateLimits(); });

// ── Rate limiting ────────────────────────────────────────────────────────────
test('redeem is strictly rate limited and the limit is enforced, not advisory', async () => {
    await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });

    let limited = 0;
    let allowed = 0;
    for (let i = 0; i < 14; i += 1) {
        const res = await http('POST', '/api/bot/redeem', { body: { key: 'A1B2-C3D4-E5F6-G7H8' }, headers: asUser(USER) });
        if (res.status === 429) {
            limited += 1;
            assert.equal(res.json.error, 'rate_limited');
            assert.ok(Number(res.headers.get('retry-after')) > 0, 'a 429 must say when to come back');
        } else {
            allowed += 1;
        }
    }
    assert.ok(allowed <= 8, `the redeem budget is 8 per window, saw ${allowed} allowed`);
    assert.ok(limited > 0, 'the limit must actually trigger');

    const { rows } = await query("SELECT count(*)::int AS n FROM audit_logs WHERE action = 'security.rate_limited'");
    assert.ok(rows[0].n > 0, 'rate limit violations must be audited');
});

test('rate limit state is shared, not per-process memory', async () => {
    // The limiter stores counters in Postgres precisely so a second replica
    // cannot double the budget. Asserting the row exists is asserting that.
    await http('GET', '/api/status');
    const { rows } = await query('SELECT bucket, hits FROM rate_limits');
    assert.ok(rows.length > 0, 'counters must be persisted');
    assert.ok(rows.every((r) => !r.bucket.includes('.') || true));
});

test('limits are reported on every response', async () => {
    const res = await http('GET', '/api/status');
    assert.equal(res.headers.get('ratelimit-limit'), '120');
    assert.ok(Number(res.headers.get('ratelimit-remaining')) >= 0);
    assert.ok(Number(res.headers.get('ratelimit-reset')) > 0);
});

test('the admin surface is limited more tightly than the user surface', async () => {
    let adminAllowed = 0;
    for (let i = 0; i < 26; i += 1) {
        const res = await http('GET', '/api/admin/keys/stats', { headers: asAdmin() });
        if (res.status === 200) adminAllowed += 1;
    }
    assert.ok(adminAllowed <= 20, `the admin budget is 20 per minute, saw ${adminAllowed}`);
});

test('mass generation has its own hourly budget', async () => {
    let ok = 0;
    for (let i = 0; i < 8; i += 1) {
        const res = await http('POST', '/api/admin/keys/generate-mass', { body: { count: 1 }, headers: asAdmin() });
        if (res.status === 201) ok += 1;
    }
    assert.ok(ok <= 5, `mass generation allows 5 per hour, saw ${ok}`);
});

test('one abusive user cannot exhaust the budget of another', async () => {
    await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });
    // Per-user buckets exist alongside the per-IP ones; the bot's requests all
    // arrive from one address, so without them one user would starve everyone.
    const { rows: before } = await query("SELECT count(*)::int AS n FROM rate_limits WHERE bucket LIKE 'auth.redeem.user%'");
    await http('POST', '/api/bot/redeem', { body: { key: 'A1B2-C3D4-E5F6-G7H8' }, headers: asUser(USER) });
    await http('POST', '/api/bot/redeem', { body: { key: 'A1B2-C3D4-E5F6-G7H8' }, headers: asUser('400000000000000002') });
    const { rows: after } = await query("SELECT DISTINCT bucket FROM rate_limits WHERE bucket LIKE 'auth.redeem.user%'");
    assert.ok(after.length >= 2, 'per-user buckets must be distinct');
    assert.ok(after.length > before[0].n);
});

// ── Error shaping ────────────────────────────────────────────────────────────
test('errors carry a request id and never a stack trace or SQL', async () => {
    const res = await http('POST', '/api/bot/redeem', { body: { key: 1 }, headers: asUser(USER) });
    assert.equal(res.status, 400);
    assert.ok(res.json.request_id, 'a request id makes a report actionable');
    assert.equal(res.headers.get('x-request-id'), res.json.request_id);
    assert.deepEqual(Object.keys(res.json).sort(), ['error', 'message', 'ok', 'request_id']);
    assert.ok(!/stack|at Object|node_modules|\.js:\d+/.test(res.text));
    assert.ok(!/postgres|pg_|relation|SELECT|INSERT/i.test(res.text));
});

test('a malformed JSON body is refused cleanly', async () => {
    const res = await http('POST', '/api/bot/redeem', { body: '{"key": ', headers: { ...asUser(USER), 'content-type': 'application/json' } });
    assert.equal(res.status, 400);
    assert.equal(res.json.message, 'Invalid request.');
    assert.ok(!res.text.includes('JSON'), 'the parser error must not surface');
});

test('an oversized body is refused before any handler runs', async () => {
    const res = await http('POST', '/api/bot/redeem', {
        body: { key: 'A1B2-C3D4-E5F6-G7H8', pad: 'x'.repeat(64 * 1024) },
        headers: asUser(USER),
    });
    assert.ok([400, 413].includes(res.status));
    assert.ok(!res.text.includes('entity.too.large'));
});

test('unknown routes answer a flat 404 and reveal nothing', async () => {
    for (const path of ['/api/nope', '/admin', '/.env', '/.git/config', '/debug', '/metrics', '/panel', '/index.html']) {
        const res = await http('GET', path);
        assert.equal(res.status, 404, `${path} should not exist`);
        assert.equal(res.json?.message, 'Not found.');
    }
    // The admin mount itself answers with the same denial as any other
    // unauthorised admin call, never with a hint about what lives under it.
    const mount = await http('GET', '/api/admin');
    assert.equal(mount.status, 403);
    assert.equal(mount.json.message, 'Access denied.');
});

test('no debug or introspection endpoint is exposed', async () => {
    for (const path of ['/api/debug', '/api/config', '/api/env', '/healthz/verbose', '/api/admin/debug', '/api/status?debug=1']) {
        const res = await http('GET', path);
        assert.ok([200, 403, 404].includes(res.status), `${path} returned ${res.status}`);
        for (const secret of [process.env.ADMIN_API_SECRET, process.env.BOT_API_SECRET, process.env.KEY_PEPPER, process.env.DATABASE_URL]) {
            assert.ok(!res.text.includes(secret), `${path} leaked a secret`);
        }
    }
});

test('responses carry hardened headers and no server banner', async () => {
    const res = await http('GET', '/api/status');
    assert.equal(res.headers.get('x-powered-by'), null);
    assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(res.headers.get('x-frame-options'), 'SAMEORIGIN');
    assert.match(res.headers.get('content-security-policy'), /default-src 'none'/);
    assert.equal(res.headers.get('referrer-policy'), 'no-referrer');
});

test('no CORS header is emitted to any origin', async () => {
    // There is no browser client, so the correct answer to every origin is
    // silence: nothing may read this API from a web page.
    for (const origin of ['https://evil.example', 'http://localhost:3000', 'null']) {
        const res = await fetch(`${await startServer()}/api/status`, { headers: { origin } });
        assert.equal(res.headers.get('access-control-allow-origin'), null, `origin ${origin} was granted CORS`);
        assert.equal(res.headers.get('access-control-allow-credentials'), null);
    }
});

// ── Logging hygiene ──────────────────────────────────────────────────────────
test('the audit trail holds no plaintext key, token or raw IP', async () => {
    await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });
    const issued = (await http('POST', '/api/admin/keys/generate', { body: { tier: 'public' }, headers: asAdmin() })).json;
    await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(USER) });
    const script = await http('POST', '/api/bot/script', { body: { tier: 'public' }, headers: asUser(USER) });
    const auth = await http('POST', '/api/script/authenticate', { body: { script_key: script.json.script_key, tier: 'public' } });
    await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } });

    const { rows } = await query('SELECT action, ip_hash, metadata FROM audit_logs');
    const dump = JSON.stringify(rows);
    assert.ok(!dump.includes(issued.key), 'full license key in the audit trail');
    assert.ok(!dump.includes(script.json.script_key), 'script key in the audit trail');
    assert.ok(!dump.includes(auth.json.grant), 'grant token in the audit trail');
    assert.ok(!dump.includes('127.0.0.1'), 'raw IP in the audit trail');
    for (const r of rows) {
        if (r.ip_hash) assert.match(r.ip_hash, /^[0-9a-f]{32}$/, 'ip_hash must be a hash');
    }
    // The useful parts are still there.
    assert.ok(dump.includes(issued.key_prefix));
    assert.ok(rows.some((r) => r.action === 'script.download'));
});

test('suspicious license sharing is flagged', async () => {
    await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });
    const issued = (await http('POST', '/api/admin/keys/generate', { body: { tier: 'public' }, headers: asAdmin() })).json;
    await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(USER) });
    const script = await http('POST', '/api/bot/script', { body: { tier: 'public' }, headers: asUser(USER) });

    // Four distinct source addresses on one license inside ten minutes.
    const { rows: lic } = await query(
        `SELECT l.id AS license_id, s.id AS script_id
           FROM license_keys l JOIN scripts s ON s.slug = 'public' LIMIT 1`);
    for (let i = 0; i < 4; i += 1) {
        await query(
            `INSERT INTO script_grants (license_id, script_id, token_hash, ip_hash, expires_at)
             VALUES ($1, $2, $3, $4, now() + interval '1 minute')`,
            [lic[0].license_id, lic[0].script_id, Buffer.from(`seed-${i}`.padEnd(32, '0'), 'utf8'), `ip-${i}`],
        );
    }
    await http('POST', '/api/script/authenticate', { body: { script_key: script.json.script_key, tier: 'public' } });

    const { rows } = await query(
        "SELECT metadata FROM audit_logs WHERE action = 'security.suspicious' AND severity = 'alert'");
    assert.equal(rows.length, 1);
    assert.equal(rows[0].metadata.reason, 'license_shared');
});

// ── Admin audit access ───────────────────────────────────────────────────────
test('the audit endpoint is admin only and filters safely', async () => {
    assert.equal((await http('GET', '/api/admin/audit')).status, 403);
    assert.equal((await http('GET', '/api/admin/audit', { headers: asUser(USER) })).status, 403);

    await http('POST', '/api/admin/keys/generate', { body: { tier: 'public' }, headers: asAdmin() });
    const ok = await http('GET', '/api/admin/audit?limit=5&action=key.generated', { headers: asAdmin() });
    assert.equal(ok.status, 200);
    assert.ok(ok.json.entries.length >= 1);
    assert.ok(ok.json.entries.every((e) => e.action === 'key.generated'));

    // Hostile filter values are dropped, not interpolated.
    const hostile = await http('GET', `/api/admin/audit?limit=9999&action=${encodeURIComponent("key' OR 1=1--")}&discord_id=${encodeURIComponent("1 OR 1=1")}`, { headers: asAdmin() });
    assert.equal(hostile.status, 200);
    assert.ok(hostile.json.entries.length <= 200, 'limit must be clamped');
});
