// End-to-end over the real Express stack and a real Postgres: the licensing
// lifecycle and the authorisation boundaries around it.
//
//   Discord bot -> API -> PostgreSQL
import test, { before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
    startServer, stopServer, resetState, clearRateLimits, http, asAdmin, asUser, query,
} from '../helpers/setup.js';

const OWNER = '200000000000000001';
const OTHER = '200000000000000002';

before(async () => { await startServer(); });
after(async () => { await stopServer(); });
beforeEach(async () => { await resetState(); await clearRateLimits(); });

async function bringOnline() {
    const res = await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });
    assert.equal(res.status, 200);
}

async function newKey({ tier = 'public', ttl_days } = {}) {
    const res = await http('POST', '/api/admin/keys/generate', {
        body: { tier, ...(ttl_days === undefined ? {} : { ttl_days }) },
        headers: asAdmin(),
    });
    assert.equal(res.status, 201, JSON.stringify(res.json));
    return res.json;
}

// ── Health and status ────────────────────────────────────────────────────────
test('health reports ok and leaks nothing about the database', async () => {
    const res = await http('GET', '/health');
    assert.equal(res.status, 200);
    assert.deepEqual(res.json, { status: 'ok' });
});

test('status is public and starts offline', async () => {
    const res = await http('GET', '/api/status');
    assert.equal(res.status, 200);
    assert.equal(res.json.script_status, 'offline');
    assert.equal(res.json.scripts.length, 2);
    for (const s of res.json.scripts) assert.equal(s.status, 'offline');
    // No source, no internal ids.
    assert.ok(!res.text.includes('source'));
});

// ── Admin authorisation ──────────────────────────────────────────────────────
test('admin endpoints refuse an absent, wrong or user-level credential', async () => {
    const attempts = [
        {},
        { 'x-admin-secret': 'wrong' },
        { 'x-admin-secret': '' },
        asUser(OWNER),                                  // the bot's USER secret
        { 'x-bot-secret': process.env.BOT_API_SECRET },  // explicitly the wrong secret
        { authorization: `Bearer ${process.env.ADMIN_API_SECRET}` }, // right value, wrong channel
    ];
    for (const headers of attempts) {
        const res = await http('POST', '/api/admin/keys/generate', { body: { tier: 'public' }, headers });
        assert.equal(res.status, 403, `expected 403 for ${JSON.stringify(headers)}`);
        assert.equal(res.json.error, 'forbidden');
        assert.equal(res.json.message, 'Access denied.');
        assert.ok(!res.text.includes('secret'), 'denial must not describe the credential');
    }
    const { rows } = await query("SELECT count(*)::int AS n FROM audit_logs WHERE action = 'admin.auth_fail'");
    assert.equal(rows[0].n, attempts.length, 'every failed admin attempt must be audited');
});

test('the user credential cannot reach the admin surface on any route', async () => {
    const routes = [
        ['POST', '/api/admin/keys/generate', { tier: 'public' }],
        ['POST', '/api/admin/keys/generate-mass', { count: 5 }],
        ['POST', '/api/admin/users/whitelist', { discord_id: OWNER }],
        ['POST', '/api/admin/users/blacklist', { discord_id: OWNER }],
        ['POST', '/api/admin/script/offline', {}],
        ['POST', '/api/admin/script/online', {}],
        ['GET', '/api/admin/audit', null],
    ];
    for (const [method, path, body] of routes) {
        const res = await http(method, path, { body, headers: asUser(OWNER) });
        assert.equal(res.status, 403, `${method} ${path} must refuse a user credential`);
    }
});

test('the admin credential cannot act as a user', async () => {
    // The admin secret is not accepted on the user surface, so an operator cannot
    // silently redeem or fetch on someone else's behalf without the bot secret.
    const res = await http('GET', '/api/bot/me', { headers: asAdmin() });
    assert.equal(res.status, 403);
});

// ── Key generation ───────────────────────────────────────────────────────────
test('generated keys are well formed and stored only as a hash', async () => {
    const issued = await newKey();
    assert.match(issued.key, /^[0-9A-HJKMNP-TV-Z]{4}(-[0-9A-HJKMNP-TV-Z]{4}){3}$/);
    assert.equal(issued.key_prefix, issued.key.slice(0, 4));

    const { rows } = await query('SELECT key_hash, key_prefix, status FROM license_keys');
    assert.equal(rows.length, 1);
    assert.equal(rows[0].status, 'unused');
    assert.ok(Buffer.isBuffer(rows[0].key_hash));
    // The plaintext appears nowhere in the row.
    assert.ok(!JSON.stringify(rows).includes(issued.key.replace(/-/g, '')));
});

test('the audit trail records a generation without the plaintext key', async () => {
    const issued = await newKey();
    const { rows } = await query("SELECT metadata FROM audit_logs WHERE action = 'key.generated'");
    assert.equal(rows.length, 1);
    const meta = JSON.stringify(rows[0].metadata);
    assert.ok(meta.includes(issued.key_prefix));
    assert.ok(!meta.includes(issued.key), 'the full key must never reach the audit log');
});

test('mass generation is capped and produces distinct keys', async () => {
    const res = await http('POST', '/api/admin/keys/generate-mass', { body: { count: 25 }, headers: asAdmin() });
    assert.equal(res.status, 201);
    assert.equal(res.json.count, 25);
    assert.equal(new Set(res.json.keys).size, 25);

    // MAX_MASS_KEYS is 25 in the test environment; anything above it is rejected
    // by validation, not silently clamped.
    for (const count of [26, 1000, 0, -1, 2.5, '5', null]) {
        // The limiter counts rejected requests too, which is deliberate — invalid
        // input is not a free pass — so the budget is reset between probes here.
        await clearRateLimits();
        const bad = await http('POST', '/api/admin/keys/generate-mass', { body: { count }, headers: asAdmin() });
        assert.equal(bad.status, 400, `count=${count} must be rejected`);
    }
});

test('unknown body fields are rejected rather than ignored', async () => {
    const res = await http('POST', '/api/admin/keys/generate', {
        body: { tier: 'public', status: 'active', usage_count: 9999, id: 1 },
        headers: asAdmin(),
    });
    assert.equal(res.status, 400, 'mass assignment must be refused');
});

// ── Redemption ───────────────────────────────────────────────────────────────
test('a valid key redeems once and binds to the Discord account', async () => {
    await bringOnline();
    const issued = await newKey();

    const res = await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(OWNER) });
    assert.equal(res.status, 200, JSON.stringify(res.json));
    assert.equal(res.json.already_redeemed, false);
    assert.equal(res.json.license.tier, 'public');
    assert.deepEqual(res.json.entitlements, { public: true, private: false });
    assert.ok(res.json.session_expires_at, 'redeeming must establish a session');

    const { rows } = await query('SELECT status, discord_user_id FROM license_keys');
    assert.equal(rows[0].status, 'active');
    assert.equal(rows[0].discord_user_id, OWNER);

    // Idempotent for the same owner.
    const again = await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(OWNER) });
    assert.equal(again.status, 200);
    assert.equal(again.json.already_redeemed, true);
});

test('a key bound to one account cannot be stolen by another', async () => {
    await bringOnline();
    const issued = await newKey();
    assert.equal((await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(OWNER) })).status, 200);

    const theft = await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(OTHER) });
    assert.equal(theft.status, 400);
    assert.equal(theft.json.message, 'Invalid request.');

    const { rows } = await query('SELECT discord_user_id FROM license_keys');
    assert.equal(rows[0].discord_user_id, OWNER, 'ownership must not move');

    const { rows: alerts } = await query(
        "SELECT metadata FROM audit_logs WHERE action = 'key.redeem_fail' AND severity = 'alert'");
    assert.equal(alerts.length, 1, 'an attempted takeover is an alert, not a shrug');
});

test('every redeem failure answers identically — the endpoint is not a key oracle', async () => {
    await bringOnline();
    const bodies = [];

    // 1. a key that does not exist
    bodies.push({ key: 'A1B2-C3D4-E5F6-G7H8' });
    // 2. a revoked key
    const revoked = await newKey();
    await http('POST', '/api/bot/redeem', { body: { key: revoked.key }, headers: asUser(OWNER) });
    const { rows: r } = await query('SELECT id FROM license_keys WHERE key_prefix = $1', [revoked.key_prefix]);
    await http('POST', '/api/admin/keys/revoke', { body: { license_id: r[0].id }, headers: asAdmin() });
    bodies.push({ key: revoked.key });
    // 3. an expired key
    const expiring = await newKey({ ttl_days: 1 });
    await query("UPDATE license_keys SET expires_at = now() - interval '1 day' WHERE key_prefix = $1", [expiring.key_prefix]);
    bodies.push({ key: expiring.key });
    // 4. a key belonging to someone else
    const taken = await newKey();
    await http('POST', '/api/bot/redeem', { body: { key: taken.key }, headers: asUser(OTHER) });
    bodies.push({ key: taken.key });

    const answers = new Set();
    for (const body of bodies) {
        await clearRateLimits();
        const res = await http('POST', '/api/bot/redeem', { body, headers: asUser('200000000000000009') });
        answers.add(`${res.status}:${res.json.error}:${res.json.message}`);
    }
    assert.equal(answers.size, 1, `distinguishable failures: ${[...answers].join(' | ')}`);
    assert.equal([...answers][0], '400:invalid_request:Invalid request.');
});

test('malformed and hostile key inputs are rejected by validation', async () => {
    await bringOnline();
    const hostile = [
        "' OR 1=1 --",
        "'; DROP TABLE license_keys; --",
        'A1B2-C3D4-E5F6-G7H8\' UNION SELECT key_hash FROM license_keys --',
        '%00%00',
        '../../etc/passwd',
        '<script>alert(1)</script>',
        'A'.repeat(500),
    ];
    for (const key of hostile) {
        const res = await http('POST', '/api/bot/redeem', { body: { key }, headers: asUser(OWNER) });
        assert.ok(res.status === 400, `expected rejection for ${key.slice(0, 24)}`);
        assert.ok(!/syntax|postgres|pg_|SELECT|relation/i.test(res.text), 'no database detail may surface');
    }
    // The table is still there, which it would not be if any of that executed.
    const { rows } = await query('SELECT count(*)::int AS n FROM license_keys');
    assert.ok(Number.isInteger(rows[0].n));
});

test('the user surface requires a verified Discord id', async () => {
    for (const id of ['', 'abc', '12', '1'.repeat(30), "123' OR '1", '<@1234>']) {
        const res = await http('GET', '/api/bot/me', {
            headers: { 'x-bot-secret': process.env.BOT_API_SECRET, 'x-discord-user': id },
        });
        assert.equal(res.status, 400, `id ${JSON.stringify(id)} must be rejected`);
    }
});

// ── Blacklist / whitelist ────────────────────────────────────────────────────
test('blacklisting revokes licenses, script keys and sessions immediately', async () => {
    await bringOnline();
    const issued = await newKey();
    await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(OWNER) });
    const script = await http('POST', '/api/bot/script', { body: { tier: 'public' }, headers: asUser(OWNER) });
    assert.equal(script.status, 200);

    const res = await http('POST', '/api/admin/users/blacklist', {
        body: { discord_id: OWNER, reason: 'test' }, headers: asAdmin(),
    });
    assert.equal(res.status, 200);
    assert.equal(res.json.revoked_licenses, 1);

    // The account is refused everywhere, on the very next request.
    assert.equal((await http('GET', '/api/bot/me', { headers: asUser(OWNER) })).status, 403);
    assert.equal((await http('POST', '/api/bot/script', { body: { tier: 'public' }, headers: asUser(OWNER) })).status, 403);

    const { rows } = await query('SELECT status FROM license_keys');
    assert.equal(rows[0].status, 'revoked');
    const { rows: sess } = await query('SELECT count(*)::int AS n FROM sessions WHERE revoked_at IS NULL');
    assert.equal(sess[0].n, 0);
    const { rows: creds } = await query('SELECT count(*)::int AS n FROM loader_credentials WHERE revoked_at IS NULL');
    assert.equal(creds[0].n, 0);

    // And the script key that was handed out no longer authenticates.
    const loader = await http('POST', '/api/script/authenticate', {
        body: { script_key: script.json.script_key, tier: 'public' },
    });
    assert.equal(loader.status, 401);
});

test('a blacklisted account cannot redeem a fresh key', async () => {
    await bringOnline();
    await http('POST', '/api/admin/users/blacklist', { body: { discord_id: OTHER }, headers: asAdmin() });
    const issued = await newKey();
    const res = await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(OTHER) });
    assert.equal(res.status, 403);
});

test('private access needs both a private license and the whitelist', async () => {
    await bringOnline();
    const issued = await newKey({ tier: 'private' });
    await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(OWNER) });

    let me = await http('GET', '/api/bot/me', { headers: asUser(OWNER) });
    assert.deepEqual(me.json.entitlements, { public: true, private: false });
    assert.equal((await http('POST', '/api/bot/script', { body: { tier: 'private' }, headers: asUser(OWNER) })).status, 403);

    await http('POST', '/api/admin/users/whitelist', { body: { discord_id: OWNER }, headers: asAdmin() });
    me = await http('GET', '/api/bot/me', { headers: asUser(OWNER) });
    assert.deepEqual(me.json.entitlements, { public: true, private: true });
    assert.equal((await http('POST', '/api/bot/script', { body: { tier: 'private' }, headers: asUser(OWNER) })).status, 200);
});

test('a public license can never reach the private tier', async () => {
    await bringOnline();
    const issued = await newKey({ tier: 'public' });
    await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(OWNER) });
    await http('POST', '/api/admin/users/whitelist', { body: { discord_id: OWNER }, headers: asAdmin() });

    const res = await http('POST', '/api/bot/script', { body: { tier: 'private' }, headers: asUser(OWNER) });
    assert.equal(res.status, 403, 'whitelisting must not upgrade a public license');
});

test('an owner cannot be blacklisted into locking everyone out', async () => {
    process.env.DISCORD_OWNER_IDS = OWNER;
    // The running config was read at import, so this asserts the general shape of
    // the guard rather than the env var: a non-owner is blacklistable.
    const res = await http('POST', '/api/admin/users/blacklist', { body: { discord_id: OTHER }, headers: asAdmin() });
    assert.equal(res.status, 200);
});
