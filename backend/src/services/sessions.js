// Authenticated sessions.
//
// A session is the server-side record that a Discord account authenticated at a
// point in time and is cleared to pull the script until it expires. It is a real
// gate, not bookkeeping: POST /api/bot/script refuses without a live one, so
// revoking sessions forces users back through Discord even though their licenses
// are untouched. Blacklisting revokes them in the same transaction as the
// licenses, which is what makes a ban take effect immediately.
//
// The token exists so each row has an unguessable handle; it is stored only as an
// HMAC under TOKEN_PEPPER and is never returned to a client, because no client
// needs to present it — the bot proves identity with its own service credential
// plus the Discord-verified user id.
import { config } from '../config/env.js';
import { query } from '../database/pool.js';
import { randomToken, hashToken, hashUserAgent } from '../security/crypto.js';

export async function create({ userId, ipHash, userAgent }) {
    const token = randomToken(32);
    const { rows } = await query(
        `INSERT INTO sessions (user_id, token_hash, ip_hash, user_agent_hash, expires_at)
         VALUES ($1, $2, $3, $4, now() + ($5 || ' seconds')::interval)
         RETURNING id, created_at, expires_at`,
        [userId, hashToken(token, 'session'), ipHash, hashUserAgent(userAgent), String(config.policy.sessionTtlSeconds)],
    );
    return { session: rows[0] };
}

/**
 * The caller's live session, if any. Touches last_used_at and re-checks the
 * user's blacklist state in the same statement, so there is no window in which a
 * revoked session is briefly accepted.
 */
export async function activeFor(userId) {
    const { rows } = await query(
        `UPDATE sessions s
            SET last_used_at = now()
          WHERE s.id = (
                SELECT id FROM sessions
                 WHERE user_id = $1 AND revoked_at IS NULL AND expires_at > now()
                 ORDER BY expires_at DESC
                 LIMIT 1)
            AND EXISTS (SELECT 1 FROM users u WHERE u.id = s.user_id AND u.blacklisted = FALSE)
        RETURNING s.id, s.created_at, s.expires_at, s.last_used_at`,
        [userId],
    );
    return rows[0] ?? null;
}

/** Create a session, or extend the caller's existing one. */
export async function ensure({ userId, ipHash, userAgent }) {
    const existing = await activeFor(userId);
    if (existing) return { session: existing, created: false };
    const { session } = await create({ userId, ipHash, userAgent });
    return { session, created: true };
}

export async function revokeAllForUser(userId) {
    const { rowCount } = await query(
        'UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
        [userId],
    );
    return rowCount;
}
