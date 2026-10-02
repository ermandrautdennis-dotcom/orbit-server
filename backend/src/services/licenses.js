// License lifecycle: generate → redeem (bind to a Discord account) → use →
// expire/revoke.
//
// Plaintext keys are returned from generate() to the caller once and are never
// written to the database, a log line or the audit trail.
import { config } from '../config/env.js';
import { query, withTransaction } from '../database/pool.js';
import {
    generateLicenseKey, normaliseLicenseKey, hashLicenseKey, keyPrefix,
} from '../security/crypto.js';

/**
 * Generate `count` keys. Insert is per-key with ON CONFLICT DO NOTHING so the
 * astronomically unlikely hash collision is retried rather than aborting a batch.
 */
export async function generate({ count = 1, tier = 'public', ttlDays = null, createdBy = null, note = null }) {
    const n = Math.min(Math.max(Number(count) || 1, 1), config.policy.maxMassKeys);
    const days = ttlDays === null || ttlDays === undefined ? config.policy.defaultKeyTtlDays : Number(ttlDays);
    const issued = [];

    await withTransaction(async (client) => {
        while (issued.length < n) {
            const plaintext = generateLicenseKey();
            const { rows } = await client.query(
                `INSERT INTO license_keys (key_hash, key_prefix, tier, created_by, note, expires_at)
                 VALUES ($1, $2, $3, $4, $5,
                         CASE WHEN $6::int > 0 THEN now() + ($6::int || ' days')::interval ELSE NULL END)
                 ON CONFLICT (key_hash) DO NOTHING
                 RETURNING id, key_prefix, tier, expires_at, created_at`,
                [hashLicenseKey(plaintext), keyPrefix(plaintext), tier, createdBy, note ?? null, days],
            );
            if (rows[0]) issued.push({ key: plaintext, ...rows[0] });
        }
    });
    return issued;
}

/**
 * Redeem a key for a Discord account.
 *
 * Returns a discriminated result rather than throwing, because the caller must
 * answer every failure mode with the *same* generic message — the reason is for
 * the audit log only. An attacker must not learn whether a key exists.
 *
 * Concurrency: the row is locked FOR UPDATE, so two simultaneous redeems of the
 * same unused key cannot both succeed.
 */
export async function redeem({ rawKey, discordUserId }) {
    const normalised = normaliseLicenseKey(rawKey);
    if (!normalised) return { ok: false, reason: 'malformed' };

    return withTransaction(async (client) => {
        const { rows } = await client.query(
            'SELECT * FROM license_keys WHERE key_hash = $1 FOR UPDATE',
            [hashLicenseKey(normalised)],
        );
        const lic = rows[0];
        if (!lic) return { ok: false, reason: 'not_found' };

        const { rows: userRows } = await client.query('SELECT * FROM users WHERE discord_id = $1', [discordUserId]);
        const user = userRows[0];
        if (!user || user.blacklisted) return { ok: false, reason: 'user_blocked', licenseId: lic.id };

        if (lic.status === 'revoked') return { ok: false, reason: 'revoked', licenseId: lic.id };
        if (lic.expires_at && new Date(lic.expires_at) <= new Date()) {
            await client.query("UPDATE license_keys SET status = 'expired' WHERE id = $1", [lic.id]);
            return { ok: false, reason: 'expired', licenseId: lic.id };
        }
        if (lic.status === 'expired') return { ok: false, reason: 'expired', licenseId: lic.id };

        // Already bound: idempotent for the owner, refused for anyone else. This
        // is the IDOR guard — a key is not transferable by guessing it twice.
        if (lic.discord_user_id && lic.discord_user_id !== discordUserId) {
            return { ok: false, reason: 'bound_to_other', licenseId: lic.id };
        }
        if (lic.discord_user_id === discordUserId && lic.status === 'active') {
            return { ok: true, already: true, license: lic };
        }

        const { rows: updated } = await client.query(
            `UPDATE license_keys
                SET status = 'active',
                    discord_user_id = $2,
                    activated_at = COALESCE(activated_at, now())
              WHERE id = $1
              RETURNING *`,
            [lic.id, discordUserId],
        );
        return { ok: true, already: false, license: updated[0] };
    });
}

/** Active, non-expired licenses for a Discord account. */
export async function activeForUser(discordUserId) {
    const { rows } = await query(
        `SELECT id, key_prefix, tier, status, created_at, activated_at, expires_at, last_used_at, usage_count
           FROM license_keys
          WHERE discord_user_id = $1 AND status = 'active'
            AND (expires_at IS NULL OR expires_at > now())
          ORDER BY activated_at DESC NULLS LAST`,
        [discordUserId],
    );
    return rows;
}

/**
 * Resolve a key presented by the Lua loader to a usable license, enforcing
 * status, expiry, ownership and the owner's blacklist state in one statement.
 */
export async function resolveForLoader(rawKey) {
    const normalised = normaliseLicenseKey(rawKey);
    if (!normalised) return { ok: false, reason: 'malformed' };

    const { rows } = await query(
        `SELECT l.*, u.blacklisted, u.whitelisted, u.username
           FROM license_keys l
           LEFT JOIN users u ON u.discord_id = l.discord_user_id
          WHERE l.key_hash = $1`,
        [hashLicenseKey(normalised)],
    );
    const lic = rows[0];
    if (!lic) return { ok: false, reason: 'not_found' };
    if (lic.status === 'revoked') return { ok: false, reason: 'revoked', license: lic };
    if (lic.status !== 'active') return { ok: false, reason: 'not_activated', license: lic };
    if (lic.expires_at && new Date(lic.expires_at) <= new Date()) {
        await query("UPDATE license_keys SET status = 'expired' WHERE id = $1", [lic.id]);
        return { ok: false, reason: 'expired', license: lic };
    }
    if (lic.blacklisted) return { ok: false, reason: 'blacklisted', license: lic };
    return { ok: true, license: lic };
}

export async function markUsed(licenseId) {
    await query(
        'UPDATE license_keys SET last_used_at = now(), usage_count = usage_count + 1 WHERE id = $1',
        [licenseId],
    );
}

export async function revokeByPrefixOrId({ id = null, reason = null }) {
    const { rows } = await query(
        `UPDATE license_keys
            SET status = 'revoked', revoked_reason = $2
          WHERE id = $1 AND status <> 'revoked'
          RETURNING id, key_prefix, discord_user_id`,
        [id, reason],
    );
    return rows[0] ?? null;
}

export async function stats() {
    const { rows } = await query(
        `SELECT status, tier, count(*)::int AS n FROM license_keys GROUP BY status, tier`,
    );
    return rows;
}
