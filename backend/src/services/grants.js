// Short-lived, single-use loader grants.
//
// The loader never sends the license key to the download endpoint. It exchanges
// the key once for a grant token that lives for GRANT_TTL_SECONDS (45s by
// default) and is bound to one license, one script and one hashed IP. Consuming
// it is an atomic UPDATE … WHERE consumed_at IS NULL, so a replayed token loses
// the race and is refused — that single statement is the replay protection.
import { config } from '../config/env.js';
import { query } from '../database/pool.js';
import { randomToken, hashToken } from '../security/crypto.js';

export async function issue({ licenseId, scriptId, ipHash }) {
    const token = randomToken(32);
    const { rows } = await query(
        `INSERT INTO script_grants (license_id, script_id, token_hash, ip_hash, expires_at)
         VALUES ($1, $2, $3, $4, now() + ($5 || ' seconds')::interval)
         RETURNING id, created_at, expires_at`,
        [licenseId, scriptId, hashToken(token, 'grant'), ipHash, String(config.policy.grantTtlSeconds)],
    );
    return { token, grant: rows[0], expiresIn: config.policy.grantTtlSeconds };
}

/**
 * Atomically consume a grant. Returns the joined license/script row or null.
 * The join re-checks the license status and the owner's blacklist state, so a
 * revocation between issue and redeem is honoured.
 */
export async function consume({ token, ipHash }) {
    const { rows } = await query(
        `UPDATE script_grants g
            SET consumed_at = now()
          WHERE g.token_hash = $1
            AND g.consumed_at IS NULL
            AND g.expires_at > now()
          RETURNING g.id, g.license_id, g.script_id, g.ip_hash`,
        [hashToken(token, 'grant')],
    );
    const grant = rows[0];
    if (!grant) return null;

    // IP binding. A grant minted for one address must not be usable from
    // another; this is what stops a leaked grant from being shared mid-flight.
    if (grant.ip_hash && ipHash && grant.ip_hash !== ipHash) {
        return { mismatch: true, grant };
    }

    const { rows: joined } = await query(
        `SELECT l.id AS license_id, l.status AS license_status, l.tier, l.expires_at, l.discord_user_id,
                u.blacklisted, s.id AS script_id, s.slug, s.version, s.status AS script_status
           FROM license_keys l
           LEFT JOIN users u ON u.discord_id = l.discord_user_id
           JOIN scripts s ON s.id = $2
          WHERE l.id = $1`,
        [grant.license_id, grant.script_id],
    );
    const row = joined[0];
    if (!row) return null;
    if (row.license_status !== 'active') return { denied: 'license_inactive', grant };
    if (row.expires_at && new Date(row.expires_at) <= new Date()) return { denied: 'license_expired', grant };
    if (row.blacklisted) return { denied: 'blacklisted', grant };
    return { ok: true, grant, ...row };
}

export async function revokeAllForLicense(licenseId) {
    await query('UPDATE script_grants SET consumed_at = now() WHERE license_id = $1 AND consumed_at IS NULL', [licenseId]);
}
