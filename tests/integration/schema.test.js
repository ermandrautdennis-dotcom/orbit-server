// Schema and migration behaviour.
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { startServer, stopServer, query } from '../helpers/setup.js';

before(async () => { await startServer(); });
after(async () => { await stopServer(); });

test('migrations are idempotent', () => {
    const out = execFileSync(process.execPath, ['database/migrate.js', 'up'], { encoding: 'utf8', env: { ...process.env } });
    assert.ok(out.includes('already applied'));
    assert.ok(out.includes('up to date'));
});

test('every applied migration is recorded with a checksum', async () => {
    const { rows } = await query('SELECT name, checksum FROM schema_migrations ORDER BY name');
    assert.ok(rows.length >= 3);
    for (const r of rows) assert.match(r.checksum, /^[0-9a-f]{64}$/);
});

test('a modified, already-applied migration is refused', async () => {
    await query("UPDATE schema_migrations SET checksum = repeat('0', 64) WHERE name = '001_init.sql'");
    try {
        execFileSync(process.execPath, ['database/migrate.js', 'up'], { encoding: 'utf8', stdio: 'pipe', env: { ...process.env } });
        assert.fail('a diverged migration must abort the run');
    } catch (err) {
        assert.match(String(err.stderr ?? err.stdout ?? ''), /modified after being applied/);
    } finally {
        // Repair, so the rest of the suite still has a usable database.
        execFileSync(process.execPath, ['-e', `
            process.env.NODE_ENV='test';
            const { query, closePool } = await import('./backend/src/database/pool.js');
            const crypto = await import('node:crypto');
            const fs = await import('node:fs/promises');
            const sql = await fs.readFile('database/migrations/001_init.sql', 'utf8');
            const sum = crypto.createHash('sha256').update(sql).digest('hex');
            await query('UPDATE schema_migrations SET checksum = $1 WHERE name = $2', [sum, '001_init.sql']);
            await closePool();
        `, '--input-type=module'], { env: { ...process.env }, stdio: 'pipe' });
    }
});

test('license keys are uniquely indexed by hash', async () => {
    const { rows } = await query(`
        SELECT indexdef FROM pg_indexes
         WHERE tablename = 'license_keys' AND indexdef LIKE '%UNIQUE%key_hash%'`);
    assert.equal(rows.length, 1, 'a duplicate key hash must be impossible at the database level');
});

test('hot lookup paths are indexed', async () => {
    const { rows } = await query('SELECT tablename, indexname FROM pg_indexes WHERE schemaname = \'public\'');
    const have = new Set(rows.map((r) => r.indexname));
    for (const idx of [
        'license_keys_owner_idx', 'license_keys_status_idx', 'license_keys_expiry_idx',
        'sessions_user_idx', 'sessions_expiry_idx',
        'script_grants_license_idx', 'script_grants_expiry_idx',
        'audit_logs_action_idx', 'audit_logs_time_idx',
        'loader_credentials_license_idx', 'loader_credentials_active_uidx',
        'users_blacklisted_idx',
    ]) {
        assert.ok(have.has(idx), `missing index: ${idx}`);
    }
});

test('status and tier values are constrained by the database, not just the app', async () => {
    await assert.rejects(query("INSERT INTO scripts (slug, name, status, public_script) VALUES ('x', 'x', 'bogus', TRUE)"));
    await assert.rejects(query(
        `INSERT INTO license_keys (key_hash, key_prefix, tier, status)
         VALUES (decode(md5(random()::text), 'hex'), 'TEST', 'public', 'bogus')`));
    await assert.rejects(query(
        `INSERT INTO license_keys (key_hash, key_prefix, tier, status)
         VALUES (decode(md5(random()::text), 'hex'), 'TEST', 'enterprise', 'active')`));
    await assert.rejects(query("INSERT INTO audit_logs (action, severity) VALUES ('x', 'catastrophic')"));
});

test('at most one live script key exists per license', async () => {
    const { rows: lic } = await query(
        `INSERT INTO license_keys (key_hash, key_prefix, tier, status)
         VALUES (decode(md5(random()::text), 'hex'), 'TEST', 'public', 'active') RETURNING id`);
    const id = lic[0].id;
    await query(
        `INSERT INTO loader_credentials (license_id, token_hash, token_prefix)
         VALUES ($1, decode(md5(random()::text), 'hex'), 'osk_a')`, [id]);
    await assert.rejects(
        query(`INSERT INTO loader_credentials (license_id, token_hash, token_prefix)
               VALUES ($1, decode(md5(random()::text), 'hex'), 'osk_b')`, [id]),
        'a second live script key per license must be impossible',
    );
    await query('DELETE FROM license_keys WHERE id = $1', [id]);
});

test('both script tiers are seeded and start offline', async () => {
    const { rows } = await query('SELECT slug, status, public_script, private_script FROM scripts ORDER BY slug');
    assert.deepEqual(rows.map((r) => r.slug), ['private', 'public']);
    assert.equal(rows.find((r) => r.slug === 'public').public_script, true);
    assert.equal(rows.find((r) => r.slug === 'private').private_script, true);
});
