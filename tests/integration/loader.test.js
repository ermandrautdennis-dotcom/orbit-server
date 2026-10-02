// The loader protocol end to end:
//   Lua loader -> API -> PostgreSQL
// plus the global kill switch, grant replay, expiry and IP binding.
import test, { before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
    startServer, stopServer, resetState, clearRateLimits, http, asAdmin, asUser, query,
} from '../helpers/setup.js';

const USER = '300000000000000001';

before(async () => { await startServer(); });
after(async () => { await stopServer(); });
beforeEach(async () => { await resetState(); await clearRateLimits(); });

async function provision({ tier = 'public', whitelist = false } = {}) {
    await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });
    if (whitelist) await http('POST', '/api/admin/users/whitelist', { body: { discord_id: USER }, headers: asAdmin() });
    const issued = (await http('POST', '/api/admin/keys/generate', { body: { tier }, headers: asAdmin() })).json;
    const redeem = await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(USER) });
    assert.equal(redeem.status, 200, JSON.stringify(redeem.json));
    const script = await http('POST', '/api/bot/script', { body: { tier }, headers: asUser(USER) });
    assert.equal(script.status, 200, JSON.stringify(script.json));
    return { issued, scriptKey: script.json.script_key, snippet: script.json.loader_snippet };
}

// ── The bootstrap ────────────────────────────────────────────────────────────
test('the loader stub is public and contains no secret', async () => {
    const res = await http('GET', '/api/script/loader');
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /text\/plain/);
    assert.equal(res.headers.get('cache-control'), 'no-store');
    assert.ok(res.text.includes('/api/script/authenticate'));

    for (const secret of [
        process.env.ADMIN_API_SECRET, process.env.BOT_API_SECRET, process.env.KEY_PEPPER,
        process.env.TOKEN_PEPPER, process.env.IP_HASH_PEPPER,
        process.env.DATABASE_URL,
    ]) {
        assert.ok(!res.text.includes(secret), 'a secret leaked into client-side Lua');
    }
    assert.ok(!res.text.includes('__API_BASE_URL__'), 'the base URL placeholder must be substituted');
});

test('the generated snippet carries only the user own script key', async () => {
    const { snippet, scriptKey } = await provision();
    assert.ok(snippet.includes(scriptKey));
    assert.ok(snippet.includes('/api/script/loader'));
    assert.ok(!snippet.includes(process.env.ADMIN_API_SECRET));
    assert.ok(!snippet.includes(process.env.BOT_API_SECRET));
});

// ── Happy path ───────────────────────────────────────────────────────────────
test('authenticate then fetch returns the protected source', async () => {
    const { scriptKey } = await provision();

    const auth = await http('POST', '/api/script/authenticate', {
        body: { script_key: scriptKey, tier: 'public', loader_version: '1.0.0' },
    });
    assert.equal(auth.status, 200, JSON.stringify(auth.json));
    assert.match(auth.json.grant, /^[A-Za-z0-9_-]{20,200}$/);
    assert.ok(auth.json.expires_in <= 45 && auth.json.expires_in > 0, 'grants must be short lived');
    assert.ok(!auth.text.includes('loadstring'), 'authenticate must not return source');

    const fetched = await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } });
    assert.equal(fetched.status, 200);
    assert.match(fetched.headers.get('content-type'), /text\/plain/);
    assert.ok(fetched.text.length > 0);
    assert.ok(fetched.headers.get('x-script-version'));

    const { rows } = await query('SELECT usage_count FROM license_keys');
    assert.ok(Number(rows[0].usage_count) >= 2, 'use must be tracked');

    const { rows: dl } = await query("SELECT count(*)::int AS n FROM audit_logs WHERE action = 'script.download'");
    assert.equal(dl[0].n, 1);
});

// ── Grant handling ───────────────────────────────────────────────────────────
test('a grant is single use — a replay is refused', async () => {
    const { scriptKey } = await provision();
    const auth = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });

    assert.equal((await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } })).status, 200);
    const replay = await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } });
    assert.equal(replay.status, 401);
    assert.equal(replay.json.message, 'Authentication failed.');
});

test('an expired grant is refused', async () => {
    const { scriptKey } = await provision();
    const auth = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    await query("UPDATE script_grants SET expires_at = now() - interval '1 second'");
    const res = await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } });
    assert.equal(res.status, 401);
});

test('a grant minted for another address is refused', async () => {
    const { scriptKey } = await provision();
    const auth = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    // Simulate the grant having been issued elsewhere.
    await query("UPDATE script_grants SET ip_hash = 'a-different-client'");
    const res = await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } });
    assert.equal(res.status, 401);

    const { rows } = await query(
        "SELECT count(*)::int AS n FROM audit_logs WHERE action = 'script.download_denied' AND severity = 'alert'");
    assert.equal(rows[0].n, 1);
});

test('a forged or guessed grant is refused', async () => {
    await provision();
    for (const grant of ['A'.repeat(43), 'not-a-grant-token-but-long-enough-xx', 'x'.repeat(199)]) {
        const res = await http('POST', '/api/script/fetch', { body: { grant } });
        assert.ok([400, 401].includes(res.status), `grant ${grant.slice(0, 8)} returned ${res.status}`);
    }
    for (const grant of ['', null, 123, {}, 'short']) {
        const res = await http('POST', '/api/script/fetch', { body: { grant } });
        assert.equal(res.status, 400);
    }
});

// ── Credential handling ──────────────────────────────────────────────────────
test('a revoked license stops the loader at authentication', async () => {
    const { scriptKey } = await provision();
    const { rows } = await query('SELECT id FROM license_keys');
    await http('POST', '/api/admin/keys/revoke', { body: { license_id: Number(rows[0].id) }, headers: asAdmin() });

    const res = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    assert.equal(res.status, 401);
});

test('an expired license stops the loader', async () => {
    const { scriptKey } = await provision();
    await query("UPDATE license_keys SET expires_at = now() - interval '1 hour'");
    const res = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    assert.equal(res.status, 401);
    const { rows } = await query('SELECT status FROM license_keys');
    assert.equal(rows[0].status, 'expired', 'expiry must be recorded, not just rejected');
});

test('re-issuing a script key invalidates the previous one', async () => {
    const { scriptKey } = await provision();
    const again = await http('POST', '/api/bot/script', { body: { tier: 'public' }, headers: asUser(USER) });
    assert.equal(again.status, 200);
    assert.equal(again.json.rotated, true);
    assert.notEqual(again.json.script_key, scriptKey);

    assert.equal((await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } })).status, 401);
    assert.equal((await http('POST', '/api/script/authenticate', { body: { script_key: again.json.script_key, tier: 'public' } })).status, 200);
});

test('a script key is never readable back from any endpoint', async () => {
    const { scriptKey } = await provision();
    const me = await http('GET', '/api/bot/me', { headers: asUser(USER) });
    assert.ok(!me.text.includes(scriptKey));
    const audit = await http('GET', '/api/admin/audit?limit=200', { headers: asAdmin() });
    assert.ok(!audit.text.includes(scriptKey), 'the audit trail must not hold the credential');
    const { rows } = await query('SELECT * FROM loader_credentials');
    assert.ok(!JSON.stringify(rows).includes(scriptKey));
});

test('a public script key cannot request the private tier', async () => {
    const { scriptKey } = await provision({ tier: 'public', whitelist: true });
    const res = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'private' } });
    assert.equal(res.status, 403);

    const { rows } = await query(
        "SELECT metadata FROM audit_logs WHERE action = 'loader.auth_fail' AND severity = 'alert'");
    assert.equal(rows.length, 1);
    assert.equal(rows[0].metadata.reason, 'tier_escalation');
});

test('losing the whitelist closes the private hub for an already-issued key', async () => {
    const { scriptKey } = await provision({ tier: 'private', whitelist: true });
    assert.equal((await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'private' } })).status, 200);

    await http('POST', '/api/admin/users/unwhitelist', { body: { discord_id: USER }, headers: asAdmin() });
    assert.equal((await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'private' } })).status, 403);
});

test('the script endpoint requires a live session', async () => {
    const { scriptKey } = await provision();
    assert.ok(scriptKey);

    // Revoking sessions forces the user back through Discord without touching
    // their license — an operational lever that is useless if it does not bite.
    await query('UPDATE sessions SET revoked_at = now()');
    const denied = await http('POST', '/api/bot/script', { body: { tier: 'public' }, headers: asUser(USER) });
    assert.equal(denied.status, 409);
    assert.equal(denied.json.error, 'session_required');

    // Re-establishing one restores access.
    assert.equal((await http('POST', '/api/bot/session', { headers: asUser(USER) })).status, 200);
    assert.equal((await http('POST', '/api/bot/script', { body: { tier: 'public' }, headers: asUser(USER) })).status, 200);
});

test('a session cannot exist without an active license', async () => {
    await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });
    const res = await http('POST', '/api/bot/session', { headers: asUser('300000000000000077') });
    assert.equal(res.status, 403);
    const { rows } = await query('SELECT count(*)::int AS n FROM sessions');
    assert.equal(rows[0].n, 0);
});

test('the protected source is never compressed', async () => {
    const { scriptKey } = await provision();
    const auth = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    const res = await http('POST', '/api/script/fetch', {
        body: { grant: auth.json.grant },
        headers: { 'accept-encoding': 'gzip, deflate, br' },
    });
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('content-encoding'), null,
        'compressing a secret-bearing response invites a compression side channel');
});

// ── The kill switch ──────────────────────────────────────────────────────────
test('scriptoffline stops authentication for users who already hold valid keys', async () => {
    const { scriptKey } = await provision();
    assert.equal((await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } })).status, 200);

    const off = await http('POST', '/api/admin/script/offline', { body: {}, headers: asAdmin() });
    assert.equal(off.status, 200);

    const res = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    assert.equal(res.status, 503);
    assert.equal(res.json.message, 'Script is currently offline.');

    const status = await http('GET', '/api/status');
    assert.equal(status.json.script_status, 'offline');

    // And back on again.
    await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });
    assert.equal((await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } })).status, 200);
});

test('scriptoffline burns grants already in flight', async () => {
    const { scriptKey } = await provision();
    const auth = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    assert.equal(auth.status, 200);

    // The switch is thrown between the two loader steps.
    await http('POST', '/api/admin/script/offline', { body: {}, headers: asAdmin() });

    const fetched = await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } });
    assert.ok([401, 503].includes(fetched.status), `expected refusal, got ${fetched.status}`);
    assert.ok(!fetched.text.includes('print('), 'no source may be served while offline');
});

test('a single tier can be taken offline without the other', async () => {
    const pub = await provision({ tier: 'public' });
    await http('POST', '/api/admin/script/offline', { body: { slug: 'public' }, headers: asAdmin() });

    assert.equal((await http('POST', '/api/script/authenticate', { body: { script_key: pub.scriptKey, tier: 'public' } })).status, 503);
    const status = await http('GET', '/api/status');
    const priv = status.json.scripts.find((s) => s.slug === 'private');
    assert.equal(priv.status, 'online', 'the other tier must be unaffected');
});

test('redeeming is refused while the script is globally offline', async () => {
    const issued = (await http('POST', '/api/admin/keys/generate', { body: { tier: 'public' }, headers: asAdmin() })).json;
    const res = await http('POST', '/api/bot/redeem', { body: { key: issued.key }, headers: asUser(USER) });
    assert.equal(res.status, 503);
    const { rows } = await query('SELECT status FROM license_keys');
    assert.equal(rows[0].status, 'unused', 'a refused redeem must not consume the key');
});

// ── Source handling ──────────────────────────────────────────────────────────
test('uploaded source is served verbatim and versioned by content', async () => {
    const source = 'print("orbit integration source")\nreturn 42\n';
    const up = await http('POST', '/api/admin/script/source', { body: { slug: 'public', source }, headers: asAdmin() });
    assert.equal(up.status, 200);
    assert.equal(Number(up.json.bytes), source.length);

    const { scriptKey } = await provision();
    const auth = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    const fetched = await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } });
    assert.equal(fetched.text, source);
    assert.equal(fetched.headers.get('x-script-version'), up.json.version);

    // The version is a content hash, so an edit changes it without anyone
    // remembering to bump a number.
    const up2 = await http('POST', '/api/admin/script/source', { body: { slug: 'public', source: `${source}-- edit\n` }, headers: asAdmin() });
    assert.notEqual(up2.json.version, up.json.version);
});

test('source is never reachable without a grant', async () => {
    await http('POST', '/api/admin/script/source', {
        body: { slug: 'private', source: 'print("TOP SECRET HUB")\n' }, headers: asAdmin(),
    });
    await http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });

    for (const path of [
        '/api/script/private', '/api/script/public', '/api/script/private/source',
        '/api/scripts/private', '/api/admin/script/private', '/api/status',
        '/api/bot/me', '/api/script/source',
    ]) {
        const res = await http('GET', path, { headers: { ...asAdmin(), ...asUser(USER) } });
        assert.ok(!res.text.includes('TOP SECRET HUB'), `${path} leaked the protected source`);
    }
});
