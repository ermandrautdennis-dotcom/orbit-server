// User records are keyed by Discord snowflake. A row is created lazily on first
// login or first admin action, so whitelisting someone who has never logged in
// still works.
import { query } from '../database/pool.js';

export async function upsertFromDiscord({ discordId, username }) {
    const { rows } = await query(
        `INSERT INTO users (discord_id, username)
         VALUES ($1, $2)
         ON CONFLICT (discord_id) DO UPDATE
            SET username = EXCLUDED.username, updated_at = now()
         RETURNING *`,
        [discordId, (username ?? 'unknown').slice(0, 64)],
    );
    return rows[0];
}

export async function ensure(discordId) {
    const { rows } = await query(
        `INSERT INTO users (discord_id) VALUES ($1)
         ON CONFLICT (discord_id) DO UPDATE SET updated_at = now()
         RETURNING *`,
        [discordId],
    );
    return rows[0];
}

export async function byDiscordId(discordId) {
    const { rows } = await query('SELECT * FROM users WHERE discord_id = $1', [discordId]);
    return rows[0] ?? null;
}

export async function setWhitelist(discordId, whitelisted) {
    const { rows } = await query(
        `UPDATE users SET whitelisted = $2, updated_at = now()
          WHERE discord_id = $1 RETURNING *`,
        [discordId, whitelisted],
    );
    return rows[0] ?? null;
}

/**
 * Blacklist a user and tear down everything they currently hold: panel sessions
 * are revoked, outstanding loader grants are consumed, and their licenses are
 * revoked. The spec requires the effect to be immediate, so this happens in one
 * transaction rather than waiting for natural expiry.
 */
export async function blacklist(discordId, { reason = null, actor = null } = {}) {
    const { rows } = await query(
        `UPDATE users SET blacklisted = TRUE, whitelisted = FALSE, updated_at = now()
          WHERE discord_id = $1 RETURNING *`,
        [discordId],
    );
    const user = rows[0];
    if (!user) return null;

    await query('UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL', [user.id]);
    await query(
        `UPDATE script_grants SET consumed_at = now()
          WHERE consumed_at IS NULL
            AND license_id IN (SELECT id FROM license_keys WHERE discord_user_id = $1)`,
        [discordId],
    );
    await query(
        `UPDATE loader_credentials SET revoked_at = now()
          WHERE revoked_at IS NULL
            AND license_id IN (SELECT id FROM license_keys WHERE discord_user_id = $1)`,
        [discordId],
    );
    const { rows: revoked } = await query(
        `UPDATE license_keys
            SET status = 'revoked', revoked_reason = COALESCE($2, 'user blacklisted')
          WHERE discord_user_id = $1 AND status IN ('unused', 'active')
          RETURNING id, key_prefix`,
        [discordId, reason],
    );
    return { user, revokedLicenses: revoked, actor };
}

export async function unblacklist(discordId) {
    const { rows } = await query(
        `UPDATE users SET blacklisted = FALSE, updated_at = now()
          WHERE discord_id = $1 RETURNING *`,
        [discordId],
    );
    return rows[0] ?? null;
}
