// Administrative API.
//
// This router is mounted behind requireAdmin(), which accepts exactly one
// credential: the ADMIN_API_SECRET held by the Discord bot. A panel session can
// never satisfy it, there is no role flag on `users` that grants it, and no
// user-facing route shares a handler with it — so privilege escalation from a
// compromised user session is not a matter of a missed check, it is structurally
// unreachable.
//
// Every route here is additionally rate limited more tightly than anything on
// the user surface, and every action is written to the audit log with the
// Discord actor that the bot asserts in X-Admin-Actor.
import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config/env.js';
import { asyncRoute } from '../middleware/errorHandler.js';
import { rateLimit, limits } from '../middleware/rateLimit.js';
import { validate, schemas } from '../middleware/validate.js';
import { requireAdmin } from '../middleware/auth.js';
import { Errors } from '../utils/errors.js';
import { audit, AuditAction, recentAudit } from '../services/audit.js';
import * as users from '../services/users.js';
import * as licenses from '../services/licenses.js';
import * as scriptSvc from '../services/scripts.js';
import * as loaderCreds from '../services/loaderCredentials.js';
import * as grants from '../services/grants.js';

export const adminRouter = Router();

adminRouter.use(requireAdmin());
adminRouter.use(rateLimit(limits.admin));

// ── Keys ─────────────────────────────────────────────────────────────────────
const genBody = z.object({
    tier: schemas.tier.default('public'),
    ttl_days: schemas.positiveDays.optional(),
    note: schemas.note,
}).strict();

adminRouter.post('/keys/generate', validate({ body: genBody }), asyncRoute(async (req, res) => {
    const [issued] = await licenses.generate({
        count: 1,
        tier: req.body.tier,
        ttlDays: req.body.ttl_days ?? null,
        createdBy: req.adminActor,
        note: req.body.note ?? null,
    });
    await audit({
        action: AuditAction.KEY_GENERATED,
        discordUserId: req.adminActor,
        ipHash: req.clientIpHash,
        requestId: req.id,
        // key_prefix only. The plaintext never reaches the log or the audit row.
        metadata: { license_id: issued.id, key_prefix: issued.key_prefix, tier: issued.tier, expires_at: issued.expires_at },
    });
    res.status(201).json({
        ok: true,
        key: issued.key,                 // returned once, to the bot, for an ephemeral reply
        key_prefix: issued.key_prefix,
        tier: issued.tier,
        expires_at: issued.expires_at,
    });
}));

const genMassBody = z.object({
    count: z.number().int().min(1).max(config.policy.maxMassKeys),
    tier: schemas.tier.default('public'),
    ttl_days: schemas.positiveDays.optional(),
    note: schemas.note,
}).strict();

adminRouter.post(
    '/keys/generate-mass',
    rateLimit(limits.adminMass),
    validate({ body: genMassBody }),
    asyncRoute(async (req, res) => {
        const issued = await licenses.generate({
            count: req.body.count,
            tier: req.body.tier,
            ttlDays: req.body.ttl_days ?? null,
            createdBy: req.adminActor,
            note: req.body.note ?? null,
        });
        await audit({
            action: AuditAction.KEY_GENERATED_MASS,
            severity: 'warn',          // bulk issuance is always worth a second look
            discordUserId: req.adminActor,
            ipHash: req.clientIpHash,
            requestId: req.id,
            metadata: { count: issued.length, tier: req.body.tier, prefixes: issued.map((k) => k.key_prefix) },
        });
        res.status(201).json({
            ok: true,
            count: issued.length,
            keys: issued.map((k) => k.key),
            tier: req.body.tier,
            expires_at: issued[0]?.expires_at ?? null,
        });
    }),
);

adminRouter.post(
    '/keys/revoke',
    validate({ body: z.object({ license_id: z.number().int().positive(), reason: schemas.reason }).strict() }),
    asyncRoute(async (req, res) => {
        const revoked = await licenses.revokeByPrefixOrId({ id: req.body.license_id, reason: req.body.reason ?? null });
        if (!revoked) throw Errors.notFound();
        await loaderCreds.revokeForLicense(revoked.id);
        // Burn grants already issued, so a loader mid-handshake gets nothing.
        await grants.revokeAllForLicense(revoked.id);
        await audit({
            action: AuditAction.KEY_REVOKED,
            severity: 'warn',
            discordUserId: req.adminActor,
            ipHash: req.clientIpHash,
            requestId: req.id,
            metadata: { license_id: revoked.id, key_prefix: revoked.key_prefix, owner: revoked.discord_user_id, reason: req.body.reason ?? null },
        });
        res.json({ ok: true, license_id: revoked.id, key_prefix: revoked.key_prefix });
    }),
);

adminRouter.get('/keys/stats', asyncRoute(async (_req, res) => {
    res.json({ ok: true, stats: await licenses.stats() });
}));

// ── Users ────────────────────────────────────────────────────────────────────
const userBody = z.object({ discord_id: schemas.discordId, reason: schemas.reason }).strict();

adminRouter.post('/users/whitelist', validate({ body: userBody }), asyncRoute(async (req, res) => {
    await users.ensure(req.body.discord_id);
    const user = await users.setWhitelist(req.body.discord_id, true);
    if (!user) throw Errors.notFound();
    await audit({
        action: AuditAction.USER_WHITELISTED,
        discordUserId: req.adminActor,
        ipHash: req.clientIpHash,
        requestId: req.id,
        metadata: { target: user.discord_id, reason: req.body.reason ?? null },
    });
    res.json({ ok: true, discord_id: user.discord_id, whitelisted: true, blacklisted: user.blacklisted });
}));

adminRouter.post('/users/unwhitelist', validate({ body: userBody }), asyncRoute(async (req, res) => {
    const user = await users.setWhitelist(req.body.discord_id, false);
    if (!user) throw Errors.notFound();
    await audit({
        action: 'user.unwhitelisted',
        severity: 'warn',
        discordUserId: req.adminActor,
        ipHash: req.clientIpHash,
        requestId: req.id,
        metadata: { target: user.discord_id, reason: req.body.reason ?? null },
    });
    res.json({ ok: true, discord_id: user.discord_id, whitelisted: false });
}));

adminRouter.post('/users/blacklist', validate({ body: userBody }), asyncRoute(async (req, res) => {
    // Refuse to lock out an operator: blacklisting an owner would strip the
    // account that can undo it.
    if (config.discord.ownerIds.includes(req.body.discord_id)) {
        throw Errors.forbidden({ reason: 'cannot_blacklist_owner' });
    }
    await users.ensure(req.body.discord_id);
    const result = await users.blacklist(req.body.discord_id, { reason: req.body.reason ?? null, actor: req.adminActor });
    if (!result) throw Errors.notFound();
    await audit({
        action: AuditAction.USER_BLACKLISTED,
        severity: 'alert',
        discordUserId: req.adminActor,
        ipHash: req.clientIpHash,
        requestId: req.id,
        metadata: {
            target: result.user.discord_id,
            reason: req.body.reason ?? null,
            revoked_licenses: result.revokedLicenses.map((l) => l.key_prefix),
        },
    });
    res.json({
        ok: true,
        discord_id: result.user.discord_id,
        blacklisted: true,
        revoked_licenses: result.revokedLicenses.length,
    });
}));

adminRouter.post('/users/unblacklist', validate({ body: userBody }), asyncRoute(async (req, res) => {
    const user = await users.unblacklist(req.body.discord_id);
    if (!user) throw Errors.notFound();
    await audit({
        action: 'user.unblacklisted',
        severity: 'warn',
        discordUserId: req.adminActor,
        ipHash: req.clientIpHash,
        requestId: req.id,
        metadata: { target: user.discord_id, reason: req.body.reason ?? null },
    });
    // Licenses revoked by the blacklist stay revoked — unblacklisting restores
    // access to the account, not to credentials that were already burned.
    res.json({ ok: true, discord_id: user.discord_id, blacklisted: false });
}));

adminRouter.get(
    '/users/:discordId',
    validate({ params: z.object({ discordId: schemas.discordId }) }),
    asyncRoute(async (req, res) => {
        const user = await users.byDiscordId(req.params.discordId);
        if (!user) throw Errors.notFound();
        const lic = await licenses.activeForUser(user.discord_id);
        res.json({
            ok: true,
            user: {
                discord_id: user.discord_id,
                username: user.username,
                whitelisted: user.whitelisted,
                blacklisted: user.blacklisted,
                created_at: user.created_at,
            },
            licenses: lic.map((l) => ({ id: l.id, key_prefix: l.key_prefix, tier: l.tier, status: l.status, expires_at: l.expires_at, usage_count: Number(l.usage_count) })),
        });
    }),
);

// ── Script switches ──────────────────────────────────────────────────────────
const scriptBody = z.object({ slug: schemas.scriptSlug.optional(), reason: schemas.reason }).strict();

adminRouter.post('/script/offline', validate({ body: scriptBody }), asyncRoute(async (req, res) => {
    // With no slug this is the global kill switch: every outstanding grant is
    // burned, so even a loader mid-handshake gets nothing.
    if (req.body.slug) await scriptSvc.setScriptStatus(req.body.slug, 'offline');
    else await scriptSvc.setGlobalStatus('offline', req.adminActor);
    await audit({
        action: AuditAction.SCRIPT_OFFLINE,
        severity: 'alert',
        discordUserId: req.adminActor,
        ipHash: req.clientIpHash,
        requestId: req.id,
        metadata: { scope: req.body.slug ?? 'global', reason: req.body.reason ?? null },
    });
    res.json({ ok: true, scope: req.body.slug ?? 'global', status: 'offline' });
}));

adminRouter.post('/script/online', validate({ body: scriptBody }), asyncRoute(async (req, res) => {
    if (req.body.slug) await scriptSvc.setScriptStatus(req.body.slug, 'online');
    else {
        await scriptSvc.setGlobalStatus('online', req.adminActor);
        // A global "online" with no per-script row online would be a confusing
        // no-op, so bring both tiers up unless they were individually disabled
        // by a later explicit call.
        await scriptSvc.setScriptStatus('public', 'online');
        await scriptSvc.setScriptStatus('private', 'online');
    }
    await audit({
        action: AuditAction.SCRIPT_ONLINE,
        severity: 'warn',
        discordUserId: req.adminActor,
        ipHash: req.clientIpHash,
        requestId: req.id,
        metadata: { scope: req.body.slug ?? 'global', reason: req.body.reason ?? null },
    });
    res.json({ ok: true, scope: req.body.slug ?? 'global', status: 'online' });
}));

adminRouter.get('/script/status', asyncRoute(async (_req, res) => {
    const [global, scripts] = await Promise.all([scriptSvc.globalStatus(), scriptSvc.listPublicMeta()]);
    res.json({
        ok: true,
        global_status: global,
        scripts: scripts.map((s) => ({
            slug: s.slug, name: s.name, version: s.version, status: s.status,
            effective: global === 'online' ? s.status : 'offline',
            updated_at: s.updated_at,
        })),
    });
}));

// Upload a new script body. Size-capped; the version becomes a content hash so
// the loader can detect a change without trusting a client-sent version string.
adminRouter.post(
    '/script/source',
    rateLimit({ name: 'admin.source', windowMs: 3_600_000, max: 20 }),
    validate({
        body: z.object({
            slug: schemas.scriptSlug,
            source: z.string().min(1).max(2_000_000),
        }).strict(),
    }),
    asyncRoute(async (req, res) => {
        const updated = await scriptSvc.setSource(req.body.slug, req.body.source);
        if (!updated) throw Errors.notFound();
        await audit({
            action: 'script.source_updated',
            severity: 'warn',
            discordUserId: req.adminActor,
            ipHash: req.clientIpHash,
            requestId: req.id,
            metadata: { slug: updated.slug, version: updated.version, bytes: Number(updated.bytes) },
        });
        res.json({ ok: true, slug: updated.slug, version: updated.version, bytes: Number(updated.bytes) });
    }),
);

// ── Audit ────────────────────────────────────────────────────────────────────
adminRouter.get('/audit', asyncRoute(async (req, res) => {
    const limit = Number.parseInt(String(req.query.limit ?? '50'), 10);
    const action = typeof req.query.action === 'string' && /^[a-z_.]{1,64}$/.test(req.query.action) ? req.query.action : null;
    const actor = typeof req.query.discord_id === 'string' && /^\d{17,20}$/.test(req.query.discord_id) ? req.query.discord_id : null;
    res.json({ ok: true, entries: await recentAudit({ limit, action, discordUserId: actor }) });
}));
