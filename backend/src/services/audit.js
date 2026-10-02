// Append-only security audit trail. Writes are best-effort: a logging failure
// must never block or fail the request it describes, but it is itself logged.
import { query } from '../database/pool.js';
import { logger, redact } from '../utils/logger.js';

export const AuditAction = {
    AUTH_LOGIN: 'auth.login',
    AUTH_LOGIN_DENIED: 'auth.login_denied',
    AUTH_LOGOUT: 'auth.logout',
    AUTH_SESSION_INVALID: 'auth.session_invalid',
    KEY_GENERATED: 'key.generated',
    KEY_GENERATED_MASS: 'key.generated_mass',
    KEY_REDEEM_OK: 'key.redeem_ok',
    KEY_REDEEM_FAIL: 'key.redeem_fail',
    KEY_REVOKED: 'key.revoked',
    KEY_EXPIRED: 'key.expired',
    LOADER_AUTH_OK: 'loader.auth_ok',
    LOADER_AUTH_FAIL: 'loader.auth_fail',
    SCRIPT_DOWNLOAD: 'script.download',
    SCRIPT_DOWNLOAD_DENIED: 'script.download_denied',
    SCRIPT_ONLINE: 'script.online',
    SCRIPT_OFFLINE: 'script.offline',
    USER_WHITELISTED: 'user.whitelisted',
    USER_BLACKLISTED: 'user.blacklisted',
    ADMIN_AUTH_FAIL: 'admin.auth_fail',
    BOT_AUTH_FAIL: 'bot.auth_fail',
    RATE_LIMITED: 'security.rate_limited',
    SUSPICIOUS: 'security.suspicious',
};

/**
 * @param {object} e
 * @param {string} e.action      one of AuditAction
 * @param {'info'|'warn'|'alert'} [e.severity]
 * @param {string|null} [e.discordUserId]
 * @param {string|null} [e.ipHash]  already-hashed IP; never a raw address
 * @param {string|null} [e.requestId]
 * @param {object} [e.metadata]     redacted before storage
 */
export async function audit(e) {
    const metadata = redact(e.metadata ?? {});
    try {
        await query(
            `INSERT INTO audit_logs (action, severity, discord_user_id, ip_hash, request_id, metadata)
             VALUES ($1, $2, $3, $4, $5, $6::jsonb)`,
            [
                e.action,
                e.severity ?? 'info',
                e.discordUserId ?? null,
                e.ipHash ?? null,
                e.requestId ?? null,
                JSON.stringify(metadata),
            ],
        );
    } catch (err) {
        logger.error('audit.write_failed', { action: e.action, err: err.message });
    }
    const level = e.severity === 'alert' ? 'warn' : 'info';
    logger[level](e.action, { discordUserId: e.discordUserId, ipHash: e.ipHash, requestId: e.requestId, ...metadata });
}

export async function recentAudit({ limit = 50, action = null, discordUserId = null } = {}) {
    const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 200);
    const { rows } = await query(
        `SELECT id, action, severity, discord_user_id, ip_hash, request_id, timestamp, metadata
           FROM audit_logs
          WHERE ($1::text IS NULL OR action = $1)
            AND ($2::text IS NULL OR discord_user_id = $2)
          ORDER BY timestamp DESC
          LIMIT $3`,
        [action, discordUserId, safeLimit],
    );
    return rows;
}
