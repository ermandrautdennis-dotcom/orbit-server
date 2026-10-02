// User-facing surface, driven exclusively by the Discord bot's panel buttons.
//
// There is no web dashboard and no browser client. Every route here requires
// BOT_API_SECRET plus the Discord user id the bot asserts, and recomputes
// authorisation from the database — the bot is trusted to say *who* is asking,
// never *what* they may have.
//
// Mounted twice, at /api/auth and /api/bot, so the documented route names from
// the API spec and the bot-oriented names both resolve to the same handlers.
import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config/env.js';
import { query } from '../database/pool.js';
import { asyncRoute } from '../middleware/errorHandler.js';
import { rateLimit, limits } from '../middleware/rateLimit.js';
import { validate, schemas } from '../middleware/validate.js';
import { requireBotUser } from '../middleware/auth.js';
import { Errors } from '../utils/errors.js';
import { normaliseLicenseKey } from '../security/crypto.js';
import { audit, AuditAction } from '../services/audit.js';
import * as sessions from '../services/sessions.js';
import * as licenses from '../services/licenses.js';
import * as scriptSvc from '../services/scripts.js';
import * as loaderCreds from '../services/loaderCredentials.js';

export const userRouter = Router();

userRouter.use(requireBotUser());

// Per-Discord-user limits on top of the per-IP limits. The bot's requests all
// come from one address, so an IP bucket alone would let one abusive user
// exhaust everyone else's budget.
const perUser = (profile) => rateLimit({ ...profile, name: `${profile.name}.user`, key: (req) => req.user.discord_id });

// ── GET /me ──────────────────────────────────────────────────────────────────
// What the panel needs to render: identity, licenses, entitlements.
userRouter.get('/me', rateLimit(limits.session), perUser(limits.session), asyncRoute(async (req, res) => {
    const active = await licenses.activeForUser(req.user.discord_id);
    res.json({
        ok: true,
        user: publicUser(req.user),
        licenses: active.map(publicLicense),
        entitlements: entitlementsFor(req.user, active),
    });
}));

// ── POST /session ────────────────────────────────────────────────────────────
// Establishes or extends the caller's session. Requires an active license, so a
// session can never exist for an account that has nothing. No token is returned:
// the bot already proves identity with its own service credential, and a bearer
// token nobody needs is only something to steal.
userRouter.post('/session', rateLimit(limits.session), perUser(limits.session), asyncRoute(async (req, res) => {
    const active = await licenses.activeForUser(req.user.discord_id);
    if (!active.length) throw Errors.forbidden({ reason: 'no_active_license' });

    const { session, created } = await sessions.ensure({
        userId: req.user.id,
        ipHash: req.clientIpHash,
        userAgent: 'discord-bot',
    });
    res.json({
        ok: true,
        created,
        expires_at: session.expires_at,
        entitlements: entitlementsFor(req.user, active),
    });
}));

// ── POST /validate ───────────────────────────────────────────────────────────
// "Is this account currently authorised?" Answers true/false and the tiers, and
// nothing about why not.
userRouter.post(
    '/validate',
    rateLimit(limits.validate),
    perUser(limits.validate),
    validate({ body: z.object({ tier: schemas.tier.optional() }).strict() }),
    asyncRoute(async (req, res) => {
        const active = await licenses.activeForUser(req.user.discord_id);
        const ent = entitlementsFor(req.user, active);
        const tier = req.body.tier;
        res.json({
            ok: true,
            valid: tier ? Boolean(ent[tier]) : (ent.public || ent.private),
            entitlements: ent,
        });
    }),
);

// ── POST /redeem ─────────────────────────────────────────────────────────────
// Every failure answers with the same status and the same message. The reason is
// written to the audit log only, so the endpoint cannot be used as an oracle for
// which keys exist.
userRouter.post(
    '/redeem',
    rateLimit(limits.redeem),
    perUser(limits.redeem),
    validate({ body: z.object({ key: schemas.licenseKey }).strict() }),
    asyncRoute(async (req, res) => {
        // The script being offline is checked first: while it is off, a redeem
        // reveals nothing about the key at all.
        const global = await scriptSvc.globalStatus();
        if (global !== 'online') {
            await audit({
                action: AuditAction.KEY_REDEEM_FAIL,
                discordUserId: req.user.discord_id,
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { reason: 'global_offline' },
            });
            throw Errors.scriptOffline();
        }

        const result = await licenses.redeem({ rawKey: req.body.key, discordUserId: req.user.discord_id });
        const prefix = normaliseLicenseKey(req.body.key)?.slice(0, 4) ?? null;

        if (!result.ok) {
            await audit({
                action: AuditAction.KEY_REDEEM_FAIL,
                severity: result.reason === 'bound_to_other' ? 'alert' : 'warn',
                discordUserId: req.user.discord_id,
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { reason: result.reason, key_prefix: prefix },
            });
            throw Errors.badRequest({ reason: result.reason });
        }

        // A successful redeem establishes a session, as the flow requires.
        const { session } = await sessions.create({
            userId: req.user.id,
            ipHash: req.clientIpHash,
            userAgent: 'discord-bot',
        });

        await audit({
            action: AuditAction.KEY_REDEEM_OK,
            discordUserId: req.user.discord_id,
            ipHash: req.clientIpHash,
            requestId: req.id,
            metadata: {
                license_id: result.license.id,
                key_prefix: result.license.key_prefix,
                tier: result.license.tier,
                already: result.already,
            },
        });

        const active = await licenses.activeForUser(req.user.discord_id);
        res.json({
            ok: true,
            already_redeemed: Boolean(result.already),
            license: publicLicense(result.license),
            entitlements: entitlementsFor(req.user, active),
            session_expires_at: session.expires_at,
        });
    }),
);

// ── POST /script ─────────────────────────────────────────────────────────────
// "Get Script". Returns the loader snippet with a freshly minted script key.
// Never returns the protected source: that only ever leaves the server through
// the loader's grant exchange.
userRouter.post(
    '/script',
    rateLimit({ name: 'user.script', windowMs: 600_000, max: 10 }),
    perUser({ name: 'user.script', windowMs: 600_000, max: 6 }),
    validate({ body: z.object({ tier: schemas.tier, rotate: z.boolean().optional() }).strict() }),
    asyncRoute(async (req, res) => {
        const tier = req.body.tier;
        const active = await licenses.activeForUser(req.user.discord_id);
        const ent = entitlementsFor(req.user, active);

        if (!ent[tier]) {
            await audit({
                action: AuditAction.SCRIPT_DOWNLOAD_DENIED,
                severity: 'warn',
                discordUserId: req.user.discord_id,
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { tier, reason: 'not_entitled' },
            });
            throw Errors.forbidden({ reason: 'not_entitled' });
        }

        // A live session is required. The bot creates one via POST /session and
        // retries, which keeps "revoke every session" a usable operational lever
        // without touching anyone's license.
        const session = await sessions.activeFor(req.user.id);
        if (!session) throw Errors.sessionRequired();

        const lic = await licenseForTier(req.user.discord_id, tier);
        if (!lic) throw Errors.forbidden({ reason: 'no_license_for_tier' });

        const existing = await loaderCreds.currentFor(lic.id);
        // A minted script key is never readable again — only replaceable. So a
        // repeat press of "Get Script" rotates it rather than echoing the old
        // one, and the previous loader stops working. That is the intended
        // trade: no endpoint anywhere can read back an issued credential.
        const { token } = await loaderCreds.mint(lic.id);

        const meta = await scriptSvc.bySlug(tier);
        const global = await scriptSvc.globalStatus();

        await audit({
            action: 'script.key_minted',
            discordUserId: req.user.discord_id,
            ipHash: req.clientIpHash,
            requestId: req.id,
            metadata: { license_id: lic.id, tier, rotated: Boolean(existing) },
        });

        res.json({
            ok: true,
            tier,
            name: meta?.name ?? tier,
            version: meta?.version ?? null,
            status: global === 'online' ? (meta?.status ?? 'offline') : 'offline',
            rotated: Boolean(existing),
            script_key: token,                       // shown once
            loader_snippet: snippetFor(tier, token),
            loader_url: `${config.publicBaseUrl}/api/script/loader`,
        });
    }),
);

async function licenseForTier(discordUserId, tier) {
    // A private license also satisfies the public tier; a public one never
    // satisfies private. Enforced here and again at loader authentication.
    const tiers = tier === 'private' ? ['private'] : ['public', 'private'];
    const { rows } = await query(
        `SELECT id, tier, expires_at FROM license_keys
          WHERE discord_user_id = $1 AND status = 'active'
            AND (expires_at IS NULL OR expires_at > now())
            AND tier = ANY($2::text[])
          ORDER BY CASE WHEN tier = 'private' THEN 0 ELSE 1 END, activated_at DESC NULLS LAST
          LIMIT 1`,
        [discordUserId, tiers],
    );
    return rows[0] ?? null;
}

export function snippetFor(tier, scriptKey = 'YOUR-SCRIPT-KEY') {
    return [
        `script_key = "${scriptKey}"`,
        `script_tier = "${tier}"`,
        `loadstring(game:HttpGet("${config.publicBaseUrl}/api/script/loader"))()`,
    ].join('\n');
}

// ── Response shaping ─────────────────────────────────────────────────────────
// Explicit allowlists, so a new database column can never leak by accident.
export function publicUser(u) {
    return {
        discord_id: u.discord_id,
        username: u.username,
        whitelisted: u.whitelisted,
        created_at: u.created_at,
    };
}

export function publicLicense(l) {
    return {
        key_prefix: l.key_prefix,
        tier: l.tier,
        status: l.status,
        activated_at: l.activated_at ?? null,
        expires_at: l.expires_at ?? null,
        last_used_at: l.last_used_at ?? null,
        usage_count: Number(l.usage_count ?? 0),
    };
}

/**
 * The single authorisation decision, computed server-side from live rows. Every
 * protected route calls this; the bot only renders the result.
 */
export function entitlementsFor(user, activeLicenses) {
    const tiers = new Set(activeLicenses.map((l) => l.tier));
    return {
        public: tiers.has('public') || tiers.has('private'),
        private: tiers.has('private') && (!config.policy.requireWhitelistForPrivate || Boolean(user.whitelisted)),
    };
}
