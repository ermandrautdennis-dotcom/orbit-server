// Service authorisation.
//
// This API has no browser clients and no user-held credential. Its callers are:
//
//   * the Discord bot, which presents BOT_API_SECRET and asserts the Discord user
//     id of the interaction it is handling. Discord has already authenticated
//     that user and signed the interaction, so the bot is the identity provider;
//   * the Discord bot again, for administrative actions, presenting the separate
//     ADMIN_API_SECRET;
//   * the Lua loader, which presents a per-license script key and gets no
//     identity at all.
//
// The two bot credentials are deliberately distinct. The user-facing surface the
// panel buttons drive (redeem, get script, status) can be reached with
// BOT_API_SECRET, which cannot generate a key, blacklist anyone or flip the
// online switch. Privilege escalation from the user surface to the admin surface
// therefore requires a second secret the user surface never sees — it is not a
// matter of a role bit or a missed check.
import { config } from '../config/env.js';
import { Errors } from '../utils/errors.js';
import { timingSafeEqual } from '../security/crypto.js';
import { audit, AuditAction } from '../services/audit.js';
import * as users from '../services/users.js';

function decodeDisplayName(encoded) {
    if (!encoded || !/^[A-Za-z0-9_-]{1,128}$/.test(encoded)) return null;
    try {
        const name = Buffer.from(encoded, 'base64url').toString('utf8')
            .replace(/[\u0000-\u001f\u007f]/g, '')
            .trim()
            .slice(0, 64);
        return name || null;
    } catch {
        return null;
    }
}

const HEADER = {
    bot: 'x-bot-secret',
    admin: 'x-admin-secret',
};

function presentedSecretIsValid(req, kind) {
    const presented = req.get(HEADER[kind]) ?? '';
    const expected = kind === 'admin' ? config.secrets.adminApiSecret : config.secrets.botApiSecret;
    if (!presented || !expected) return false;
    return timingSafeEqual(presented, expected);
}

/**
 * Admin surface. Accepts ADMIN_API_SECRET only. X-Admin-Actor carries the
 * Discord id of the operator for the audit trail.
 */
export function requireAdmin() {
    return async (req, _res, next) => {
        if (!presentedSecretIsValid(req, 'admin')) {
            await audit({
                action: AuditAction.ADMIN_AUTH_FAIL,
                severity: 'alert',
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { path: req.path, actorClaim: req.get('x-admin-actor') ?? null },
            });
            // Same body as every other denial: no hint that the path exists or
            // that the secret was merely wrong.
            return next(Errors.forbidden({ reason: 'admin_denied' }));
        }
        const actor = req.get('x-admin-actor') ?? null;
        if (actor && !/^\d{17,20}$/.test(actor)) return next(Errors.badRequest({ reason: 'bad_actor' }));
        req.adminActor = actor;
        return next();
    };
}

/**
 * User surface, called by the bot on behalf of a Discord user.
 *
 * Requires BOT_API_SECRET plus X-Discord-User. The user row is loaded (and
 * created on first contact) and the blacklist is re-checked here on every
 * request, so a blacklist takes effect on the very next button press rather than
 * at some later expiry.
 */
export function requireBotUser() {
    return async (req, _res, next) => {
        if (!presentedSecretIsValid(req, 'bot')) {
            await audit({
                action: AuditAction.BOT_AUTH_FAIL,
                severity: 'alert',
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { path: req.path },
            });
            return next(Errors.forbidden({ reason: 'bot_denied' }));
        }

        const discordId = req.get('x-discord-user') ?? '';
        if (!/^\d{17,20}$/.test(discordId)) return next(Errors.badRequest({ reason: 'bad_discord_user' }));

        try {
            // Display name arrives base64url encoded, so no header-encoding
            // trick or embedded newline can reach the database. It is cosmetic
            // only — nothing is authorised on the strength of it.
            const encoded = req.get('x-discord-username');
            const username = decodeDisplayName(encoded);
            const user = username
                ? await users.upsertFromDiscord({ discordId, username })
                : await users.ensure(discordId);

            if (user.blacklisted) {
                await audit({
                    action: AuditAction.AUTH_LOGIN_DENIED,
                    severity: 'warn',
                    discordUserId: discordId,
                    ipHash: req.clientIpHash,
                    requestId: req.id,
                    metadata: { reason: 'blacklisted', path: req.path },
                });
                return next(Errors.forbidden({ reason: 'blacklisted' }));
            }
            req.user = user;
            return next();
        } catch (err) {
            return next(err);
        }
    };
}
