// Central, fail-fast configuration. Every secret comes from the environment;
// nothing in this repository ships a usable default for a security-critical
// value. In production a missing or weak secret aborts boot rather than
// silently degrading.
import 'dotenv/config';

const MIN_SECRET_BYTES = 32;

function str(name, fallback = undefined) {
    const v = process.env[name];
    if (v === undefined || v === '') return fallback;
    return v;
}

function bool(name, fallback = false) {
    const v = str(name);
    if (v === undefined) return fallback;
    return ['1', 'true', 'yes', 'on'].includes(v.toLowerCase());
}

function int(name, fallback) {
    const v = str(name);
    if (v === undefined) return fallback;
    const n = Number.parseInt(v, 10);
    if (!Number.isFinite(n)) throw new Error(`env ${name} must be an integer`);
    return n;
}

function list(name) {
    const v = str(name, '');
    return v.split(',').map((s) => s.trim()).filter(Boolean);
}

const errors = [];
const NODE_ENV = str('NODE_ENV', 'development');
const isProd = NODE_ENV === 'production';
const isTest = NODE_ENV === 'test';

// A secret is acceptable when it decodes to >= 32 bytes of entropy. Base64url,
// base64 and hex all pass; a short passphrase does not.
function secret(name, { required = true } = {}) {
    const v = str(name);
    if (!v) {
        if (required && !isTest) errors.push(`${name} is required (generate one with: npm run secrets)`);
        return isTest ? `test-only-${name}-padding-0123456789abcdef0123456789` : undefined;
    }
    let bytes;
    try {
        bytes = Buffer.from(v, /^[0-9a-fA-F]+$/.test(v) ? 'hex' : 'base64url').length;
    } catch {
        bytes = Buffer.byteLength(v, 'utf8');
    }
    if (Math.max(bytes, Buffer.byteLength(v, 'utf8') * 0.6) < MIN_SECRET_BYTES) {
        errors.push(`${name} is too weak: needs at least ${MIN_SECRET_BYTES} bytes of entropy`);
    }
    return v;
}

const PUBLIC_BASE_URL = (str('PUBLIC_BASE_URL', 'http://localhost:3000')).replace(/\/+$/, '');
if (isProd && !PUBLIC_BASE_URL.startsWith('https://')) {
    errors.push('PUBLIC_BASE_URL must be an https:// URL in production');
}

export const config = {
    nodeEnv: NODE_ENV,
    isProd,
    isTest,
    port: int('PORT', 3000),
    publicBaseUrl: PUBLIC_BASE_URL,
    trustProxy: bool('TRUST_PROXY', false),

    db: {
        url: str('DATABASE_URL'),
        ssl: bool('DATABASE_SSL', false),
        poolMax: int('DATABASE_POOL_MAX', 10),
    },

    secrets: {
        keyPepper: secret('KEY_PEPPER'),
        tokenPepper: secret('TOKEN_PEPPER'),
        ipHashPepper: secret('IP_HASH_PEPPER'),
        adminApiSecret: secret('ADMIN_API_SECRET'),
        botApiSecret: secret('BOT_API_SECRET'),
    },

    discord: {
        clientId: str('DISCORD_CLIENT_ID'),
        botToken: str('DISCORD_BOT_TOKEN'),
        guildId: str('DISCORD_GUILD_ID'),
        adminRoleIds: list('DISCORD_ADMIN_ROLE_IDS'),
        ownerIds: list('DISCORD_OWNER_IDS'),
    },

    apiBaseUrl: (str('API_BASE_URL', PUBLIC_BASE_URL)).replace(/\/+$/, ''),

    policy: {
        sessionTtlSeconds: int('SESSION_TTL_SECONDS', 43200),
        grantTtlSeconds: Math.min(int('GRANT_TTL_SECONDS', 45), 300),
        defaultKeyTtlDays: int('DEFAULT_KEY_TTL_DAYS', 30),
        maxMassKeys: Math.min(int('MAX_MASS_KEYS', 100), 500),
        requireWhitelistForPrivate: bool('REQUIRE_WHITELIST_FOR_PRIVATE', true),
        maxSessionsPerLicense: int('MAX_SESSIONS_PER_LICENSE', 3),
    },
};

if (!config.db.url && !isTest) errors.push('DATABASE_URL is required');

// Behind a platform proxy (Railway, Fly, Cloudflare, any ingress) every request
// arrives from the proxy, so without TRUST_PROXY all per-IP rate limits and all
// audit IP hashes collapse onto one value. That is a real weakening, so it is an
// error in production rather than a warning.
if (isProd && !config.trustProxy) {
    errors.push('TRUST_PROXY must be true in production when the app runs behind a reverse proxy (Railway always does); set it to false only when the app is directly exposed');
}

if (isProd) {
    const distinct = new Set(Object.values(config.secrets));
    if (distinct.size !== Object.keys(config.secrets).length) {
        errors.push('KEY_PEPPER, TOKEN_PEPPER, IP_HASH_PEPPER, ADMIN_API_SECRET and BOT_API_SECRET must all be distinct');
    }
}

export function assertConfig() {
    if (errors.length) {
        // Printed to stderr only — never returned over HTTP.
        throw new Error(`Invalid configuration:\n  - ${errors.join('\n  - ')}`);
    }
}

export const configErrors = errors;
