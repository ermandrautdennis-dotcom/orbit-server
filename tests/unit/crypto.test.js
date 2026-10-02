// Key generation, normalisation and hashing. These are the primitives the whole
// licensing model rests on, so they are tested for shape, determinism and
// distribution rather than just "does it return a string".
import test from 'node:test';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.KEY_PEPPER ??= 'dGVzdC1rZXktcGVwcGVyLTAxMjM0NTY3ODlhYmNkZWZnaGlqa2xtbm8';
process.env.TOKEN_PEPPER ??= 'dGVzdC10b2tlbi1wZXBwZXItMDEyMzQ1Njc4OWFiY2RlZmdoaWprbG0';
process.env.IP_HASH_PEPPER ??= 'dGVzdC1pcC1wZXBwZXItMDEyMzQ1Njc4OWFiY2RlZmdoaWprbG1ub3A';

const {
    generateLicenseKey, normaliseLicenseKey, hashLicenseKey, hashToken, hashIp,
    keyPrefix, randomToken, timingSafeEqual, hashSecret, verifySecret,
} = await import('../../backend/src/security/crypto.js');

test('generated keys match XXXX-XXXX-XXXX-XXXX', () => {
    for (let i = 0; i < 200; i += 1) {
        assert.match(generateLicenseKey(), /^[0-9A-HJKMNP-TV-Z]{4}(-[0-9A-HJKMNP-TV-Z]{4}){3}$/);
    }
});

test('generated keys are unique across a large sample', () => {
    const seen = new Set();
    for (let i = 0; i < 20_000; i += 1) seen.add(generateLicenseKey());
    assert.equal(seen.size, 20_000, 'collision in 20k keys implies a broken generator');
});

test('key symbols are uniformly distributed (no modulo bias)', () => {
    // Rejection sampling should leave every alphabet symbol roughly equally
    // likely. A naive `byte % 32` would skew the low symbols measurably here.
    const counts = new Map();
    const draws = 40_000;
    for (let i = 0; i < draws / 16; i += 1) {
        for (const ch of generateLicenseKey().replace(/-/g, '')) {
            counts.set(ch, (counts.get(ch) ?? 0) + 1);
        }
    }
    const expected = draws / 32;
    for (const [, n] of counts) {
        assert.ok(Math.abs(n - expected) < expected * 0.25, 'symbol distribution is skewed');
    }
    assert.equal(counts.size, 32, 'generator must use the whole alphabet');
});

test('keys avoid ambiguous symbols', () => {
    const sample = Array.from({ length: 500 }, () => generateLicenseKey()).join('');
    for (const ch of ['I', 'L', 'O', 'U']) assert.ok(!sample.includes(ch), `alphabet must exclude ${ch}`);
});

test('normalisation is tolerant of formatting and ambiguous glyphs', () => {
    const key = 'A1B2-C3D4-E5F6-G7H8';
    assert.equal(normaliseLicenseKey(key), key);
    assert.equal(normaliseLicenseKey(key.toLowerCase()), key);
    assert.equal(normaliseLicenseKey(' a1b2 c3d4 e5f6 g7h8 '), key);
    assert.equal(normaliseLicenseKey('a1b2c3d4e5f6g7h8'), key);
    // I/L -> 1, O -> 0, U -> V, so a transcription slip still resolves.
    assert.equal(normaliseLicenseKey('IIII-OOOO-LLLL-UUUU'), '1111-0000-1111-VVVV');
});

test('normalisation rejects anything that is not a 16-symbol key', () => {
    for (const bad of ['', 'short', null, undefined, 42, {}, 'A1B2-C3D4-E5F6-G7H', 'A1B2-C3D4-E5F6-G7H8X', "' OR 1=1--"]) {
        assert.equal(normaliseLicenseKey(bad), null, `should reject ${JSON.stringify(bad)}`);
    }
});

test('license hashing is deterministic, 32 bytes, and not reversible to the key', () => {
    const key = generateLicenseKey();
    const a = hashLicenseKey(key);
    const b = hashLicenseKey(key);
    assert.equal(a.length, 32);
    assert.ok(a.equals(b), 'same key must hash identically for lookup to work');
    assert.ok(!a.toString('hex').includes(key.replace(/-/g, '')), 'hash must not contain the key');
    assert.ok(!hashLicenseKey(generateLicenseKey()).equals(a));
});

test('token and ip hashing are domain separated', () => {
    const value = 'same-input';
    assert.ok(!hashToken(value, 'session').equals(hashToken(value, 'grant')),
        'a session token must not collide with a grant token of the same value');
    assert.ok(!hashToken(value, 'session').equals(hashToken(value, 'loader')));
    assert.equal(hashIp('1.2.3.4'), hashIp('1.2.3.4'));
    assert.notEqual(hashIp('1.2.3.4'), hashIp('1.2.3.5'));
    assert.equal(hashIp(null), null);
    assert.ok(!hashIp('1.2.3.4').includes('1.2.3.4'));
});

test('tokens carry 256 bits and are url safe', () => {
    const t = randomToken(32);
    assert.match(t, /^[A-Za-z0-9_-]{43}$/);
    const seen = new Set(Array.from({ length: 5_000 }, () => randomToken(32)));
    assert.equal(seen.size, 5_000);
});

test('keyPrefix exposes only the first group', () => {
    const key = generateLicenseKey();
    assert.equal(keyPrefix(key), key.slice(0, 4));
});

test('timingSafeEqual compares correctly across lengths', () => {
    assert.ok(timingSafeEqual('abc', 'abc'));
    assert.ok(!timingSafeEqual('abc', 'abd'));
    assert.ok(!timingSafeEqual('abc', 'abcdef'), 'must not throw or pass on length mismatch');
    assert.ok(!timingSafeEqual('', 'x'));
    assert.ok(!timingSafeEqual(undefined, 'x'));
});

test('hashSecret produces a verifiable, salted hash', async () => {
    const stored = await hashSecret('correct horse battery staple');
    assert.ok(stored.startsWith('$argon2') || stored.startsWith('$scrypt$'), `unexpected format: ${stored.slice(0, 12)}`);
    assert.ok(await verifySecret('correct horse battery staple', stored));
    assert.ok(!await verifySecret('wrong', stored));
    assert.ok(!await verifySecret('correct horse battery staple', 'garbage'));
    // Distinct salts, so identical inputs do not produce identical hashes.
    assert.notEqual(stored, await hashSecret('correct horse battery staple'));
});
