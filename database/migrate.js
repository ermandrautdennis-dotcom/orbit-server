#!/usr/bin/env node
// Forward-only SQL migration runner. Each file in ./migrations runs once inside
// a transaction and is recorded with its SHA-256 so an edited, already-applied
// migration is rejected instead of silently diverging between environments.
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { assertConfig, config } from '../backend/src/config/env.js';
import { getPool, closePool } from '../backend/src/database/pool.js';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'migrations');

async function ensureTable(client) {
    await client.query(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
            name       TEXT        PRIMARY KEY,
            checksum   TEXT        NOT NULL,
            applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )`);
}

async function load() {
    const files = (await fs.readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
    return Promise.all(files.map(async (name) => {
        const sql = await fs.readFile(path.join(dir, name), 'utf8');
        return { name, sql, checksum: crypto.createHash('sha256').update(sql).digest('hex') };
    }));
}

async function up() {
    const pool = getPool();
    const client = await pool.connect();
    try {
        await ensureTable(client);
        const { rows } = await client.query('SELECT name, checksum FROM schema_migrations');
        const applied = new Map(rows.map((r) => [r.name, r.checksum]));
        const migrations = await load();

        for (const m of migrations) {
            const prev = applied.get(m.name);
            if (prev && prev !== m.checksum) {
                throw new Error(`migration ${m.name} was modified after being applied — add a new migration instead`);
            }
            if (prev) { console.log(`= ${m.name} (already applied)`); continue; }
            console.log(`+ ${m.name}`);
            await client.query('BEGIN');
            try {
                await client.query(m.sql);
                await client.query('INSERT INTO schema_migrations (name, checksum) VALUES ($1, $2)', [m.name, m.checksum]);
                await client.query('COMMIT');
            } catch (err) {
                await client.query('ROLLBACK');
                throw new Error(`migration ${m.name} failed: ${err.message}`);
            }
        }
        console.log('migrations up to date');
    } finally {
        client.release();
    }
}

async function status() {
    const client = await getPool().connect();
    try {
        await ensureTable(client);
        const { rows } = await client.query('SELECT name, applied_at FROM schema_migrations ORDER BY name');
        const applied = new Set(rows.map((r) => r.name));
        for (const m of await load()) {
            console.log(`${applied.has(m.name) ? '[x]' : '[ ]'} ${m.name}`);
        }
    } finally {
        client.release();
    }
}

const cmd = process.argv[2] ?? 'up';
try {
    assertConfig();
    if (!config.db.url) throw new Error('DATABASE_URL is not set');
    if (cmd === 'up') await up();
    else if (cmd === 'status') await status();
    else { console.error('usage: migrate.js [up|status]'); process.exitCode = 2; }
} catch (err) {
    console.error(`migration error: ${err.message}`);
    process.exitCode = 1;
} finally {
    await closePool();
}
