// Structured JSON logging with hard redaction. Anything whose key looks like a
// credential is replaced before serialisation, so a careless call site cannot
// leak a token, a license key or a secret into stdout (which on Railway is a
// persisted, searchable log stream).
import { config } from '../config/env.js';

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const threshold = LEVELS[process.env.LOG_LEVEL ?? (config.isProd ? 'info' : 'debug')] ?? 20;

const SENSITIVE = /(^|_)(key|token|secret|password|pepper|authorization|cookie|signature|grant)(s)?($|_)/i;

// Fields that merely *look* like credentials but are deliberately non-secret and
// are what makes the audit trail useful: a key's first group, a stored hash, a
// count. Redacting these would blind the logs for no gain.
const SAFE = new Set([
    'key_prefix', 'key_hash', 'token_prefix', 'token_hash', 'key_id', 'license_key_prefix',
    'grant_id', 'script_key_prefix', 'key_count', 'keys_generated',
]);

function redactValue(v) {
    if (typeof v !== 'string') return '[redacted]';
    if (v.length <= 4) return '[redacted]';
    return `[redacted:${v.length}]`;
}

export function redact(input, depth = 0) {
    if (depth > 6) return '[depth]';
    if (input === null || input === undefined) return input;
    if (Array.isArray(input)) return input.map((v) => redact(v, depth + 1));
    if (Buffer.isBuffer(input)) return `[bytes:${input.length}]`;
    if (typeof input === 'object') {
        const out = {};
        for (const [k, v] of Object.entries(input)) {
            const lower = k.toLowerCase();
            out[k] = (!SAFE.has(lower) && SENSITIVE.test(k)) ? redactValue(v) : redact(v, depth + 1);
        }
        return out;
    }
    return input;
}

function emit(level, event, fields) {
    if (LEVELS[level] < threshold) return;
    const line = JSON.stringify({
        ts: new Date().toISOString(),
        level,
        event,
        ...redact(fields ?? {}),
    });
    if (level === 'error' || level === 'warn') process.stderr.write(`${line}\n`);
    else process.stdout.write(`${line}\n`);
}

export const logger = {
    debug: (e, f) => emit('debug', e, f),
    info: (e, f) => emit('info', e, f),
    warn: (e, f) => emit('warn', e, f),
    error: (e, f) => emit('error', e, f),
};
