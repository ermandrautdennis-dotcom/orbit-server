// Single pg Pool for the process. Every call site uses parameterised queries —
// there is no string-interpolated SQL anywhere in this codebase, which is what
// actually prevents SQL injection (an ORM would not add protection here).
import pg from 'pg';
import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';

const { Pool } = pg;

let pool = null;

export function getPool() {
    if (pool) return pool;
    pool = new Pool({
        connectionString: config.db.url,
        max: config.db.poolMax,
        idleTimeoutMillis: 30_000,
        connectionTimeoutMillis: 10_000,
        // Railway's internal network is already private; external Postgres over
        // the internet must use TLS.
        ssl: config.db.ssl ? { rejectUnauthorized: true } : undefined,
        application_name: 'orbit-auth',
    });
    pool.on('error', (err) => {
        // An idle client erroring must not take the process down.
        logger.error('pool.idle_error', { err: err.message });
    });
    return pool;
}

/** Run a parameterised query. `text` is always a literal in the caller. */
export async function query(text, params = []) {
    const started = process.hrtime.bigint();
    try {
        return await getPool().query(text, params);
    } catch (err) {
        // The driver's message can contain row values. Log it internally with a
        // short SQL fingerprint and re-throw a scrubbed error for the handler.
        logger.error('db.query_failed', {
            sql: text.replace(/\s+/g, ' ').slice(0, 120),
            code: err.code,
            detail: err.message,
        });
        const scrubbed = new Error('database error');
        scrubbed.code = err.code;
        scrubbed.isDbError = true;
        throw scrubbed;
    } finally {
        const ms = Number(process.hrtime.bigint() - started) / 1e6;
        if (ms > 500) logger.warn('db.slow_query', { ms: Math.round(ms), sql: text.replace(/\s+/g, ' ').slice(0, 120) });
    }
}

/** Run `fn` inside a transaction, rolling back on any throw. */
export async function withTransaction(fn) {
    const client = await getPool().connect();
    try {
        await client.query('BEGIN');
        const result = await fn(client);
        await client.query('COMMIT');
        return result;
    } catch (err) {
        try { await client.query('ROLLBACK'); } catch { /* connection already gone */ }
        throw err;
    } finally {
        client.release();
    }
}

export async function closePool() {
    if (!pool) return;
    const p = pool;
    pool = null;
    await p.end();
}
