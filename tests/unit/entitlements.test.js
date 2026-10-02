// Entitlement resolution is the single authorisation decision in the system, so
// it is tested in isolation from HTTP.
import test from 'node:test';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.REQUIRE_WHITELIST_FOR_PRIVATE = 'true';
const { entitlementsFor } = await import('../../backend/src/routes/user.js');

const user = (over = {}) => ({ discord_id: '1', username: 'u', whitelisted: false, blacklisted: false, ...over });

test('no licenses means no access', () => {
    assert.deepEqual(entitlementsFor(user(), []), { public: false, private: false });
});

test('a public license grants public only', () => {
    assert.deepEqual(entitlementsFor(user(), [{ tier: 'public' }]), { public: true, private: false });
});

test('a private license grants public too, but needs the whitelist for private', () => {
    assert.deepEqual(entitlementsFor(user(), [{ tier: 'private' }]), { public: true, private: false });
    assert.deepEqual(entitlementsFor(user({ whitelisted: true }), [{ tier: 'private' }]), { public: true, private: true });
});

test('whitelisting alone grants nothing', () => {
    assert.deepEqual(entitlementsFor(user({ whitelisted: true }), []), { public: false, private: false });
});

test('a whitelisted user with only a public license still cannot reach private', () => {
    assert.deepEqual(entitlementsFor(user({ whitelisted: true }), [{ tier: 'public' }]), { public: true, private: false });
});
