// Cryptographic primitives. Three distinct jobs, three distinct constructions:
//
//  1. License keys are generated with 80 bits of CSPRNG entropy and must be
//     looked up by value, so they are indexed by a *deterministic* keyed hash
//     (HMAC-SHA256 under KEY_PEPPER). A salted password hash cannot be looked
//     up without scanning every row; a keyed hash over a high-entropy secret is
//     the correct construction here — there is no dictionary to attack, and an
//     attacker with the database still cannot derive a key without the pepper.
//  2. Session and grant tokens are 256-bit CSPRNG values, likewise stored as
//     HMAC-SHA256 under TOKEN_PEPPER.
//  3. Low-entropy, human-chosen secrets (none ship by default, but the helper
//     exists for operator passwords) go through Argon2id when the optional
//     native module is present, and scrypt with memory-hard parameters when it
//     is not. Both are strong; the fallback keeps `npm install` working on
//     hosts without a toolchain.
import crypto from 'node:crypto';
import { config } from '../config/env.js';

let argon2 = null;
try {
    argon2 = await import('@node-rs/argon2');
} catch {
    argon2 = null;
}

const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // no I, L, O, U

/** Cryptographically secure random bytes. */
export function randomBytes(n) {
    return crypto.randomBytes(n);
}

/** URL-safe random token. 32 bytes = 256 bits. */
export function randomToken(bytes = 32) {
    return crypto.randomBytes(bytes).toString('base64url');
}

/**
 * Generate a license key in XXXX-XXXX-XXXX-XXXX form.
 * 16 Crockford base32 symbols = 80 bits of entropy, drawn with rejection
 * sampling so the distribution is exactly uniform (a plain modulo over 256
 * would bias the first 8 symbols).
 */
export function generateLicenseKey(groups = 4, groupLen = 4) {
    const total = groups * groupLen;
    const out = [];
    while (out.length < total) {
        for (const b of crypto.randomBytes(total * 2)) {
            if (b >= 256 - (256 % CROCKFORD.length)) continue; // reject bias tail
            out.push(CROCKFORD[b % CROCKFORD.length]);
            if (out.length === total) break;
        }
    }
    const parts = [];
    for (let i = 0; i < groups; i += 1) parts.push(out.slice(i * groupLen, (i + 1) * groupLen).join(''));
    return parts.join('-');
}

/**
 * Normalise a user-supplied key: uppercase, strip everything that is not a
 * Crockford symbol, re-group. This makes `abcd efgh…`, `ABCD-EFGH…` and
 * lowercase pastes hash identically without ever interpolating input into SQL.
 */
export function normaliseLicenseKey(raw) {
    if (typeof raw !== 'string') return null;
    const cleaned = raw.toUpperCase().replace(/[^0-9A-Z]/g, '')
        .replace(/I/g, '1').replace(/L/g, '1').replace(/O/g, '0').replace(/U/g, 'V');
    if (cleaned.length !== 16) return null;
    if (![...cleaned].every((c) => CROCKFORD.includes(c))) return null;
    return cleaned.match(/.{4}/g).join('-');
}

function hmac(pepper, value) {
    return crypto.createHmac('sha256', Buffer.from(String(pepper), 'utf8'))
        .update(Buffer.from(String(value), 'utf8'))
        .digest();
}

/** Deterministic lookup hash for a (already normalised) license key. */
export function hashLicenseKey(normalisedKey) {
    return hmac(config.secrets.keyPepper, `license:${normalisedKey}`);
}

/** Deterministic lookup hash for a session or grant token. */
export function hashToken(token, kind = 'session') {
    return hmac(config.secrets.tokenPepper, `${kind}:${token}`);
}

/** Pseudonymous, non-reversible IP label for logs. Truncated to 32 hex chars. */
export function hashIp(ip) {
    if (!ip) return null;
    return hmac(config.secrets.ipHashPepper, `ip:${ip}`).toString('hex').slice(0, 32);
}

/** Pseudonymous user-agent label, for session-binding heuristics only. */
export function hashUserAgent(ua) {
    if (!ua) return null;
    return hmac(config.secrets.ipHashPepper, `ua:${ua}`).toString('hex').slice(0, 32);
}

/** Short, non-secret prefix stored alongside a key so admins can identify it. */
export function keyPrefix(normalisedKey) {
    return normalisedKey.slice(0, 4);
}

/** Constant-time comparison that tolerates differing lengths. */
export function timingSafeEqual(a, b) {
    const ba = Buffer.isBuffer(a) ? a : Buffer.from(String(a ?? ''), 'utf8');
    const bb = Buffer.isBuffer(b) ? b : Buffer.from(String(b ?? ''), 'utf8');
    // Hash both sides first so lengths always match and no length leaks.
    const ha = crypto.createHash('sha256').update(ba).digest();
    const hb = crypto.createHash('sha256').update(bb).digest();
    return crypto.timingSafeEqual(ha, hb);
}

const SCRYPT_PARAMS = { N: 1 << 15, r: 8, p: 1, maxmem: 96 * 1024 * 1024 };

/** Hash a low-entropy secret. Argon2id when available, scrypt otherwise. */
export async function hashSecret(plaintext) {
    if (argon2) {
        return argon2.hash(plaintext, {
            algorithm: argon2.Algorithm?.Argon2id ?? 2,
            memoryCost: 19456,
            timeCost: 2,
            parallelism: 1,
        });
    }
    const salt = crypto.randomBytes(16);
    const dk = await new Promise((res, rej) => {
        crypto.scrypt(plaintext, salt, 32, SCRYPT_PARAMS, (e, k) => (e ? rej(e) : res(k)));
    });
    return `$scrypt$N=${SCRYPT_PARAMS.N},r=${SCRYPT_PARAMS.r},p=${SCRYPT_PARAMS.p}$${salt.toString('base64url')}$${dk.toString('base64url')}`;
}

/** Verify a hash produced by hashSecret(). */
export async function verifySecret(plaintext, stored) {
    if (typeof stored !== 'string' || !stored) return false;
    if (stored.startsWith('$argon2')) {
        if (!argon2) return false;
        try { return await argon2.verify(stored, plaintext); } catch { return false; }
    }
    const m = /^\$scrypt\$N=(\d+),r=(\d+),p=(\d+)\$([^$]+)\$(.+)$/.exec(stored);
    if (!m) return false;
    const [, N, r, p, saltB64, dkB64] = m;
    const salt = Buffer.from(saltB64, 'base64url');
    const expected = Buffer.from(dkB64, 'base64url');
    const dk = await new Promise((res, rej) => {
        crypto.scrypt(plaintext, salt, expected.length,
            { N: Number(N), r: Number(r), p: Number(p), maxmem: SCRYPT_PARAMS.maxmem },
            (e, k) => (e ? rej(e) : res(k)));
    });
    return crypto.timingSafeEqual(dk, expected);
}

export const argon2Available = Boolean(argon2);
