// Script keys: the rotatable credential the Lua loader carries.
//
// Stored as an HMAC under TOKEN_PEPPER, exactly like a session token. The
// plaintext is returned once at mint time and then only ever presented by the
// client. Resolving one re-checks the license, its expiry and the owner's
// blacklist state in a single statement, so revocation is immediate.
import { query } from '../database/pool.js';
import { randomToken, hashToken } from '../security/crypto.js';

const PREFIX = 'osk_'; // "orbit script key" — makes leaked keys greppable

/** Mint (or rotate) the script key for a license. Returns the plaintext once. */
export async function mint(licenseId) {
    const token = `${PREFIX}${randomToken(32)}`;
    await query('UPDATE loader_credentials SET revoked_at = now() WHERE license_id = $1 AND revoked_at IS NULL', [licenseId]);
    const { rows } = await query(
        `INSERT INTO loader_credentials (license_id, token_hash, token_prefix)
         VALUES ($1, $2, $3)
         RETURNING id, token_prefix, created_at`,
        [licenseId, hashToken(token, 'loader'), token.slice(0, 12)],
    );
    return { token, credential: rows[0] };
}

/** The live script key metadata for a license, if one has been minted. */
export async function currentFor(licenseId) {
    const { rows } = await query(
        `SELECT id, token_prefix, created_at, last_used_at, usage_count
           FROM loader_credentials
          WHERE license_id = $1 AND revoked_at IS NULL`,
        [licenseId],
    );
    return rows[0] ?? null;
}

/**
 * Resolve a presented script key. Returns { ok, license } or { ok: false,
 * reason }. The reason is for the audit log; callers answer generically.
 */
export async function resolve(token) {
    if (typeof token !== 'string' || !token.startsWith(PREFIX) || token.length < 20 || token.length > 200) {
        return { ok: false, reason: 'malformed' };
    }
    const { rows } = await query(
        `SELECT c.id AS credential_id, l.*, u.blacklisted, u.whitelisted
           FROM loader_credentials c
           JOIN license_keys l ON l.id = c.license_id
           LEFT JOIN users u ON u.discord_id = l.discord_user_id
          WHERE c.token_hash = $1 AND c.revoked_at IS NULL`,
        [hashToken(token, 'loader')],
    );
    const row = rows[0];
    if (!row) return { ok: false, reason: 'not_found' };
    if (row.status === 'revoked') return { ok: false, reason: 'revoked', license: row };
    if (row.status !== 'active') return { ok: false, reason: 'not_activated', license: row };
    if (row.expires_at && new Date(row.expires_at) <= new Date()) {
        await query("UPDATE license_keys SET status = 'expired' WHERE id = $1", [row.id]);
        return { ok: false, reason: 'expired', license: row };
    }
    if (row.blacklisted) return { ok: false, reason: 'blacklisted', license: row };
    return { ok: true, license: row, credentialId: row.credential_id };
}

export async function markUsed(credentialId) {
    await query(
        'UPDATE loader_credentials SET last_used_at = now(), usage_count = usage_count + 1 WHERE id = $1',
        [credentialId],
    );
}

export async function revokeForLicense(licenseId) {
    await query('UPDATE loader_credentials SET revoked_at = now() WHERE license_id = $1 AND revoked_at IS NULL', [licenseId]);
}
