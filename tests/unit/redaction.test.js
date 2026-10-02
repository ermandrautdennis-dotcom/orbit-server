// The logger is the last line of defence against a careless call site writing a
// credential into a persisted log stream, so its redaction is tested directly.
import test from 'node:test';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
const { redact } = await import('../../backend/src/utils/logger.js');

test('credential-shaped keys are redacted at every depth', () => {
    const out = redact({
        script_key: 'osk_abcdefghijklmnop',
        key: 'ABCD-EFGH-IJKL-MNOP',
        token: 'tok_secret_value_here',
        admin_secret: 'super-secret',
        password: 'hunter2',
        key_pepper: 'pepper',
        authorization: 'Bearer xyz',
        cookie: 'a=b',
        signature: 'sig',
        grant: 'g',
        nested: { tokens: 'plural', inner: { session_token: 'deep' } },
        list: [{ api_key: 'k' }],
    });
    const serialised = JSON.stringify(out);
    for (const leak of ['osk_abcdefghijklmnop', 'ABCD-EFGH-IJKL-MNOP', 'tok_secret_value_here',
        'super-secret', 'hunter2', 'Bearer xyz', 'deep', 'plural']) {
        assert.ok(!serialised.includes(leak), `leaked: ${leak}`);
    }
});

test('non-sensitive fields survive intact', () => {
    // key_prefix and key_hash look credential-shaped but are deliberately not
    // secret, and the audit trail is useless without them.
    const out = redact({ key_prefix: 'A1B2', key_hash: 'deadbeef', tier: 'private', usage_count: 7, discord_id: '123', ok: true });
    assert.deepEqual(out, { key_prefix: 'A1B2', key_hash: 'deadbeef', tier: 'private', usage_count: 7, discord_id: '123', ok: true });
});

test('the safe list does not weaken redaction of real credentials', () => {
    const out = redact({ script_key: 'osk_leak', key: 'ABCD', api_key: 'k', script_key_prefix: 'osk_abc' });
    assert.ok(!JSON.stringify(out).includes('osk_leak'));
    assert.ok(!JSON.stringify(out).includes('"k"'));
    assert.equal(out.script_key_prefix, 'osk_abc');
});

test('buffers are summarised, not dumped', () => {
    assert.equal(redact({ hash: Buffer.alloc(32) }).hash, '[bytes:32]');
});

test('redaction terminates on deeply nested and cyclic-looking input', () => {
    let node = { leaf: true };
    for (let i = 0; i < 40; i += 1) node = { child: node };
    assert.doesNotThrow(() => JSON.stringify(redact(node)));
});

test('null and undefined pass through', () => {
    assert.equal(redact(null), null);
    assert.equal(redact(undefined), undefined);
});
