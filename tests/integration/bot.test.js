// The Discord layer against the real API and a real database:
//   panel button / modal -> bot handler -> API -> PostgreSQL
//
// The interaction objects are stubs with the same surface discord.js gives a
// handler. Everything below the handler is the production code path, including
// both service credentials and all the server-side authorisation.
import test, { before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

const PORT = 38217;
// The bot's API client reads this at import time, so it is set before the config
// singleton is loaded by anything else.
process.env.API_BASE_URL = `http://127.0.0.1:${PORT}`;
process.env.PUBLIC_BASE_URL = `http://127.0.0.1:${PORT}`;
process.env.DISCORD_ADMIN_ROLE_IDS = '900000000000000001';
process.env.DISCORD_OWNER_IDS = '500000000000000099';

const setup = await import('../helpers/setup.js');
const { http, asAdmin, resetState, clearRateLimits, query } = setup;
const panel = await import('../../bot/interactions/panel.js');
const { isAuthorisedAdmin } = await import('../../bot/utils/permissions.js');

const USER = '500000000000000001';

before(async () => { await setup.startServer(PORT); });
after(async () => { await setup.stopServer(); });
beforeEach(async () => { await resetState(); await clearRateLimits(); });

// ── Interaction stubs ────────────────────────────────────────────────────────
function makeInteraction({ customId = '', userId = USER, fields = {} } = {}) {
    const captured = { replies: [], modals: [], deferred: false, replied: false };
    return {
        captured,
        customId,
        user: { id: userId, username: 'tester', globalName: 'Tester' },
        isButton: () => !customId.endsWith('_modal'),
        isModalSubmit: () => customId.endsWith('_modal'),
        fields: { getTextInputValue: (k) => fields[k] },
        async deferReply() { captured.deferred = true; },
        async editReply(payload) { captured.replies.push(payload); return payload; },
        async reply(payload) { captured.replied = true; captured.replies.push(payload); return payload; },
        async showModal(modal) { captured.modals.push(modal.toJSON()); },
    };
}

const lastEmbed = (i) => i.captured.replies.at(-1).embeds[0].toJSON();

async function issueKey(tier = 'public') {
    const res = await http('POST', '/api/admin/keys/generate', { body: { tier }, headers: asAdmin() });
    assert.equal(res.status, 201, JSON.stringify(res.json));
    return res.json;
}

const bringOnline = () => http('POST', '/api/admin/script/online', { body: {}, headers: asAdmin() });

// ── The panel message ────────────────────────────────────────────────────────
test('the panel renders three buttons with stateless ids', () => {
    const built = panel.buildPanel();
    const embed = built.embeds[0].toJSON();
    assert.equal(embed.title, 'SCRIPT AUTH');
    for (const part of ['Redeem Key', 'Get Script', 'Status']) assert.ok(embed.description.includes(part));

    const ids = built.components[0].toJSON().components.map((c) => c.custom_id);
    assert.deepEqual(ids, [panel.IDS.redeem, panel.IDS.getScript, panel.IDS.status]);
    // Nothing user-specific or secret in a component id, which is what lets the
    // panel keep working across restarts.
    for (const id of ids) {
        assert.match(id, /^orbit:[a-z]+$/);
        assert.ok(!id.includes(USER));
    }
    assert.ok(!JSON.stringify(built).includes(process.env.BOT_API_SECRET));
    assert.ok(!JSON.stringify(built).includes(process.env.ADMIN_API_SECRET));
});

// ── Redeem via the modal ─────────────────────────────────────────────────────
test('the redeem button opens a modal with one license field', async () => {
    const i = makeInteraction({ customId: panel.IDS.redeem });
    assert.equal(await panel.routePanelInteraction(i), true);
    assert.equal(i.captured.modals.length, 1);
    const modal = i.captured.modals[0];
    assert.equal(modal.custom_id, panel.IDS.redeemModal);
    assert.equal(modal.components[0].components[0].custom_id, panel.IDS.keyField);
});

test('a valid key submitted through the modal activates and binds the license', async () => {
    await bringOnline();
    const issued = await issueKey();

    const i = makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: issued.key } });
    assert.equal(await panel.routePanelInteraction(i), true);

    const embed = lastEmbed(i);
    assert.equal(embed.title, 'Key redeemed');
    assert.ok(embed.description.includes('public'));

    const { rows } = await query('SELECT status, discord_user_id FROM license_keys');
    assert.equal(rows[0].status, 'active');
    assert.equal(rows[0].discord_user_id, USER);
});

test('the modal accepts a sloppily pasted key', async () => {
    await bringOnline();
    const issued = await issueKey();
    const sloppy = ` ${issued.key.replace(/-/g, ' ').toLowerCase()} `;

    const i = makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: sloppy } });
    await panel.routePanelInteraction(i);
    assert.equal(lastEmbed(i).title, 'Key redeemed');
});

test('every bad key gets the same reply, and it names no reason', async () => {
    await bringOnline();
    const good = await issueKey();
    const firstOwner = makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: good.key }, userId: '500000000000000055' });
    await panel.routePanelInteraction(firstOwner);

    const cases = ['A1B2-C3D4-E5F6-G7H8', good.key];   // nonexistent, then someone else's
    const seen = new Set();
    for (const key of cases) {
        await clearRateLimits();
        const i = makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: key } });
        await panel.routePanelInteraction(i);
        const e = lastEmbed(i);
        seen.add(`${e.title}|${e.description}`);
    }
    assert.equal(seen.size, 1, `distinguishable replies: ${[...seen].join(' /// ')}`);
    assert.ok([...seen][0].includes('could not be redeemed'));
    for (const word of ['expired', 'revoked', 'blacklist', 'already bound', 'does not exist']) {
        assert.ok(!([...seen][0].toLowerCase().includes(word)), `reply disclosed "${word}"`);
    }
});

test('a malformed key never reaches the API', async () => {
    const i = makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: 'nope' } });
    await panel.routePanelInteraction(i);
    assert.equal(lastEmbed(i).title, 'Invalid request.');
    const { rows } = await query("SELECT count(*)::int AS n FROM audit_logs WHERE action = 'key.redeem_fail'");
    assert.equal(rows[0].n, 0, 'an obvious typo should not spend the rate limit budget');
});

// ── Get Script ───────────────────────────────────────────────────────────────
test('get script refuses an account with no license', async () => {
    await bringOnline();
    const i = makeInteraction({ customId: panel.IDS.getScript });
    await panel.routePanelInteraction(i);
    const e = lastEmbed(i);
    assert.equal(e.title, 'Not authorised');
    assert.ok(!e.description.includes('loadstring'));
});

test('get script delivers a loader snippet with a fresh script key', async () => {
    await bringOnline();
    const issued = await issueKey();
    await panel.routePanelInteraction(makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: issued.key } }));

    const i = makeInteraction({ customId: panel.IDS.getScript });
    await panel.routePanelInteraction(i);
    const e = lastEmbed(i);

    assert.ok(e.description.includes('loadstring(game:HttpGet('));
    assert.ok(e.description.includes('/api/script/loader'));
    assert.match(e.description, /script_key = "osk_[A-Za-z0-9_-]+"/);
    assert.ok(e.description.includes('script_tier = "public"'));

    // And nothing privileged rode along.
    for (const secret of [process.env.ADMIN_API_SECRET, process.env.BOT_API_SECRET,
        process.env.KEY_PEPPER, process.env.TOKEN_PEPPER, process.env.DATABASE_URL, issued.key]) {
        assert.ok(!e.description.includes(secret), 'the Discord reply leaked a secret');
    }

    // The key it handed out actually works against the loader protocol.
    const scriptKey = /script_key = "(osk_[A-Za-z0-9_-]+)"/.exec(e.description)[1];
    const auth = await http('POST', '/api/script/authenticate', { body: { script_key: scriptKey, tier: 'public' } });
    assert.equal(auth.status, 200);
    const fetched = await http('POST', '/api/script/fetch', { body: { grant: auth.json.grant } });
    assert.equal(fetched.status, 200);
});

test('a dual-tier license is asked which tier it wants', async () => {
    await bringOnline();
    const priv = await issueKey('private');
    await panel.routePanelInteraction(makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: priv.key } }));
    await http('POST', '/api/admin/users/whitelist', { body: { discord_id: USER }, headers: asAdmin() });

    const i = makeInteraction({ customId: panel.IDS.getScript });
    await panel.routePanelInteraction(i);
    const reply = i.captured.replies.at(-1);
    const ids = reply.components[0].toJSON().components.map((c) => c.custom_id);
    assert.deepEqual(ids, [panel.IDS.scriptPublic, panel.IDS.scriptPrivate]);

    const chosen = makeInteraction({ customId: panel.IDS.scriptPrivate });
    await panel.routePanelInteraction(chosen);
    assert.ok(lastEmbed(chosen).description.includes('script_tier = "private"'));
});

test('pressing the private-tier button without the entitlement is refused server-side', async () => {
    await bringOnline();
    const pub = await issueKey('public');
    await panel.routePanelInteraction(makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: pub.key } }));

    // A forged component id claiming the private tier gets nothing: the backend
    // recomputes the entitlement rather than trusting the button.
    const i = makeInteraction({ customId: panel.IDS.scriptPrivate });
    await panel.routePanelInteraction(i);
    const e = lastEmbed(i);
    assert.equal(e.title, 'Get Script failed');
    assert.ok(!e.description.includes('loadstring'));
});

test('get script reports offline instead of handing out a loader', async () => {
    await bringOnline();
    const issued = await issueKey();
    await panel.routePanelInteraction(makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: issued.key } }));
    await http('POST', '/api/admin/script/offline', { body: {}, headers: asAdmin() });

    const i = makeInteraction({ customId: panel.IDS.getScript });
    await panel.routePanelInteraction(i);
    const e = lastEmbed(i);
    assert.ok(e.title.includes('Offline'));
    assert.ok(!e.description.includes('loadstring'));
});

test('a lapsed session is re-established transparently', async () => {
    await bringOnline();
    const issued = await issueKey();
    await panel.routePanelInteraction(makeInteraction({ customId: panel.IDS.redeemModal, fields: { license_key: issued.key } }));

    // The session the redeem created is gone; the handler must recover rather
    // than showing the user an error.
    await query('UPDATE sessions SET revoked_at = now()');

    const i = makeInteraction({ customId: panel.IDS.getScript });
    await panel.routePanelInteraction(i);
    assert.ok(lastEmbed(i).description.includes('loadstring'), 'the loader should still be delivered');

    const { rows } = await query('SELECT count(*)::int AS n FROM sessions WHERE revoked_at IS NULL');
    assert.equal(rows[0].n, 1, 'exactly one fresh session should have been established');
});

// ── Status ───────────────────────────────────────────────────────────────────
test('the status button reports the live switch state', async () => {
    const off = makeInteraction({ customId: panel.IDS.status });
    await panel.routePanelInteraction(off);
    assert.ok(lastEmbed(off).title.includes('Offline'));

    await bringOnline();
    const on = makeInteraction({ customId: panel.IDS.status });
    await panel.routePanelInteraction(on);
    assert.ok(lastEmbed(on).title.includes('Online'));
    // Status is public information; it must not carry license or user detail.
    assert.ok(!lastEmbed(on).description.includes('osk_'));
});

// ── Routing ──────────────────────────────────────────────────────────────────
test('interactions the panel does not own are ignored', async () => {
    for (const customId of ['some:other:button', 'orbit', 'orbit:admin', '']) {
        const i = makeInteraction({ customId });
        assert.equal(await panel.routePanelInteraction(i), false);
        assert.equal(i.captured.replies.length, 0);
    }
});

// ── Command authorisation ────────────────────────────────────────────────────
test('admin command authorisation requires a configured role or owner id', () => {
    const base = {
        user: { id: '500000000000000123' },
        guildId: process.env.DISCORD_GUILD_ID || null,
        inGuild: () => true,
        member: { roles: { cache: new Map() } },
    };
    assert.equal(isAuthorisedAdmin(base), false, 'a plain member must be refused');

    assert.equal(isAuthorisedAdmin({
        ...base,
        member: { roles: { cache: new Map([['900000000000000001', {}]]) } },
    }), true, 'the configured admin role must pass');

    assert.equal(isAuthorisedAdmin({
        ...base,
        member: { roles: { cache: new Map([['000000000000000000', {}]]) } },
    }), false, 'an unrelated role must not pass');

    assert.equal(isAuthorisedAdmin({ ...base, user: { id: '500000000000000099' } }), true, 'an owner id must pass');

    // A DM has no roles to check, so only an owner gets through.
    assert.equal(isAuthorisedAdmin({ ...base, inGuild: () => false }), false);
    assert.equal(isAuthorisedAdmin({ ...base, user: { id: '500000000000000099' }, inGuild: () => false }), true);
    assert.equal(isAuthorisedAdmin({ ...base, user: {} }), false);
});
