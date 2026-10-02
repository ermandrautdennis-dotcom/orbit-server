#!/usr/bin/env node
// Process entry point. Validates configuration before binding a port — a
// misconfigured deployment fails loudly at boot instead of serving requests with
// a weak or missing secret.
import { assertConfig, config } from './config/env.js';
import { createApp } from './app.js';
import { logger } from './utils/logger.js';
import { query, closePool } from './database/pool.js';
import { startRateLimitJanitor } from './middleware/rateLimit.js';
import { argon2Available } from './security/crypto.js';

try {
    assertConfig();
} catch (err) {
    process.stderr.write(`${err.message}\n`);
    process.exit(1);
}

const app = createApp();

async function waitForDatabase(attempts = 10) {
    for (let i = 1; i <= attempts; i += 1) {
        try {
            await query('SELECT 1');
            return;
        } catch (err) {
            if (i === attempts) throw err;
            const wait = Math.min(1000 * 2 ** (i - 1), 8000);
            logger.warn('db.connect_retry', { attempt: i, waitMs: wait });
            await new Promise((r) => setTimeout(r, wait));
        }
    }
}

await waitForDatabase();

// Fail fast if migrations have not been run: a missing table would otherwise
// surface as a stream of 500s.
try {
    await query('SELECT 1 FROM scripts LIMIT 1');
    await query('SELECT 1 FROM loader_credentials LIMIT 1');
} catch {
    process.stderr.write('Database schema is missing or out of date. Run: npm run migrate\n');
    process.exit(1);
}

const janitor = startRateLimitJanitor();

const server = app.listen(config.port, '0.0.0.0', () => {
    logger.info('server.listening', {
        port: config.port,
        env: config.nodeEnv,
        baseUrl: config.publicBaseUrl,
        kdf: argon2Available ? 'argon2id' : 'scrypt',
    });
});

server.headersTimeout = 20_000;
server.requestTimeout = 30_000;
server.keepAliveTimeout = 10_000;

let shuttingDown = false;
async function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info('server.shutdown', { signal });
    clearInterval(janitor);
    server.close(async () => {
        await closePool();
        process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
    logger.error('process.unhandled_rejection', { reason: reason instanceof Error ? reason.message : String(reason) });
});
process.on('uncaughtException', (err) => {
    logger.error('process.uncaught_exception', { err: err.message, stack: err.stack?.split('\n').slice(0, 5) });
    shutdown('uncaughtException');
});
