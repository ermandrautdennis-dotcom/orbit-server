// The Lua loader protocol. These are the only unauthenticated-by-session routes
// in the system: the loader presents a per-license script key and nothing else.
//
// The protected source leaves this process through exactly one handler —
// POST /api/script/fetch — and only after four independent server-side checks:
// a valid single-use grant, a live license of the right tier, the owner's
// blacklist state, and both the global and per-script online switches. The
// Discord panel never receives source; it receives a loader snippet.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config/env.js';
import { asyncRoute } from '../middleware/errorHandler.js';
import { rateLimit, limits } from '../middleware/rateLimit.js';
import { validate, schemas } from '../middleware/validate.js';
import { Errors } from '../utils/errors.js';
import { audit, AuditAction } from '../services/audit.js';
import { query } from '../database/pool.js';
import * as scriptSvc from '../services/scripts.js';
import * as licenses from '../services/licenses.js';
import * as grants from '../services/grants.js';
import * as loaderCreds from '../services/loaderCredentials.js';

export const scriptRouter = Router();

const LOADER_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../../lua/loader.lua');
let loaderCache = null;

async function loaderSource() {
    if (loaderCache && Date.now() - loaderCache.at < 60_000) return loaderCache.text;
    const raw = await fs.readFile(LOADER_PATH, 'utf8');
    // The only substitution is the public API base URL. No secret is ever
    // templated into client-side Lua.
    const text = raw.replaceAll('__API_BASE_URL__', config.publicBaseUrl);
    loaderCache = { text, at: Date.now() };
    return text;
}

// ── GET /api/script/loader ───────────────────────────────────────────────────
// The bootstrap the exploit HttpGets. Public by design and carries no secret:
// it reads a `script_key` global that the user pastes above it.
scriptRouter.get('/script/loader', rateLimit(limits.scriptLoader), asyncRoute(async (_req, res) => {
    res.type('text/plain; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.send(await loaderSource());
}));

// ── POST /api/script/authenticate ────────────────────────────────────────────
// Step 1 of the loader protocol. Exchanges a script key for a short-lived,
// single-use, IP-bound grant. Never returns source.
const authenticateBody = z.object({
    script_key: z.string().min(16).max(200),
    tier: schemas.tier.optional(),
    loader_version: z.string().max(32).optional(),
}).strict();

scriptRouter.post(
    '/script/authenticate',
    rateLimit(limits.loaderAuth),
    validate({ body: authenticateBody }),
    asyncRoute(async (req, res) => {
        const slug = req.body.tier ?? 'public';

        // Global/per-script switch first: when the script is off, nothing else
        // about the caller's license is revealed.
        const servable = await scriptSvc.servable(slug);
        if (!servable.ok) {
            await audit({
                action: AuditAction.LOADER_AUTH_FAIL,
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { slug, reason: servable.reason },
            });
            throw Errors.scriptOffline();
        }

        const resolved = await loaderCreds.resolve(req.body.script_key);
        if (!resolved.ok) {
            await audit({
                action: AuditAction.LOADER_AUTH_FAIL,
                severity: resolved.reason === 'blacklisted' ? 'alert' : 'warn',
                discordUserId: resolved.license?.discord_user_id ?? null,
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { slug, reason: resolved.reason },
            });
            throw Errors.unauthorized({ reason: resolved.reason });
        }

        const lic = resolved.license;
        // Tier authorisation, server-side. A 'public' license cannot reach the
        // private hub by sending tier="private".
        const tierOk = slug === 'public' ? true : lic.tier === 'private';
        const whitelistOk = slug !== 'private' || !config.policy.requireWhitelistForPrivate || Boolean(lic.whitelisted);
        if (!tierOk || !whitelistOk) {
            await audit({
                action: AuditAction.LOADER_AUTH_FAIL,
                severity: 'alert',
                discordUserId: lic.discord_user_id,
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { slug, reason: tierOk ? 'not_whitelisted' : 'tier_escalation', license_id: lic.id },
            });
            throw Errors.forbidden({ reason: 'not_entitled' });
        }

        await flagConcurrency({ req, licenseId: lic.id, discordUserId: lic.discord_user_id });

        const { token, expiresIn } = await grants.issue({
            licenseId: lic.id,
            scriptId: servable.script.id,
            ipHash: req.clientIpHash,
        });
        await loaderCreds.markUsed(resolved.credentialId);
        await licenses.markUsed(lic.id);
        await audit({
            action: AuditAction.LOADER_AUTH_OK,
            discordUserId: lic.discord_user_id,
            ipHash: req.clientIpHash,
            requestId: req.id,
            metadata: { slug, license_id: lic.id, loader_version: req.body.loader_version ?? null },
        });

        res.setHeader('Cache-Control', 'no-store');
        res.json({
            ok: true,
            grant: token,
            expires_in: expiresIn,
            script: { slug, version: servable.script.version },
        });
    }),
);

/**
 * Soft abuse signal: many distinct source addresses redeeming grants for one
 * license in a short window is how a shared or resold key looks. Logged as an
 * alert rather than enforced, so a legitimate user on a changing IP is not
 * locked out by a heuristic.
 */
async function flagConcurrency({ req, licenseId, discordUserId }) {
    const { rows } = await query(
        `SELECT count(DISTINCT ip_hash)::int AS ips
           FROM script_grants
          WHERE license_id = $1 AND created_at > now() - interval '10 minutes'`,
        [licenseId],
    );
    const ips = rows[0]?.ips ?? 0;
    if (ips > config.policy.maxSessionsPerLicense) {
        await audit({
            action: AuditAction.SUSPICIOUS,
            severity: 'alert',
            discordUserId,
            ipHash: req.clientIpHash,
            requestId: req.id,
            metadata: { reason: 'license_shared', license_id: licenseId, distinct_ips_10m: ips },
        });
    }
}

// ── POST /api/script/fetch ───────────────────────────────────────────────────
// Step 2. Consumes the grant and returns the Lua source as text/plain.
scriptRouter.post(
    '/script/fetch',
    rateLimit(limits.loaderFetch),
    validate({ body: z.object({ grant: schemas.opaqueToken }).strict() }),
    asyncRoute(async (req, res) => {
        const consumed = await grants.consume({ token: req.body.grant, ipHash: req.clientIpHash });
        if (!consumed || consumed.mismatch || consumed.denied) {
            await audit({
                action: AuditAction.SCRIPT_DOWNLOAD_DENIED,
                severity: consumed?.mismatch ? 'alert' : 'warn',
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { reason: consumed?.mismatch ? 'grant_ip_mismatch' : (consumed?.denied ?? 'grant_invalid') },
            });
            throw Errors.unauthorized({ reason: 'grant_invalid' });
        }

        // Re-check the switches at delivery time: /scriptoffline between the two
        // steps must win, even though the grant itself is still fresh.
        const servable = await scriptSvc.servable(consumed.slug);
        if (!servable.ok) {
            await audit({
                action: AuditAction.SCRIPT_DOWNLOAD_DENIED,
                ipHash: req.clientIpHash,
                requestId: req.id,
                metadata: { reason: servable.reason, slug: consumed.slug },
            });
            throw Errors.scriptOffline();
        }

        const row = await scriptSvc.sourceBySlug(consumed.slug);
        if (!row) throw Errors.scriptOffline();

        await licenses.markUsed(consumed.license_id);
        await audit({
            action: AuditAction.SCRIPT_DOWNLOAD,
            discordUserId: consumed.discord_user_id,
            ipHash: req.clientIpHash,
            requestId: req.id,
            metadata: { slug: consumed.slug, license_id: consumed.license_id, bytes: row.source.length },
        });

        res.setHeader('Cache-Control', 'no-store');
        res.setHeader('X-Script-Version', row.version);
        res.type('text/plain; charset=utf-8').send(row.source);
    }),
);
