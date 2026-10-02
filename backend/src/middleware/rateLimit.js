// Postgres-backed fixed-window rate limiting.
//
// Why not express-rate-limit's default store: it is per-process memory, so two
// Railway replicas double every limit and a restart clears them. A single
// atomic UPSERT against a shared table costs one round trip and holds across
// instances and restarts.
//
// Buckets are keyed by hashed IP and/or authenticated subject, never by any
// client-supplied header, so a caller cannot rotate its way out of a limit by
// forging X-Forwarded-For.
import { query } from '../database/pool.js';
import { Errors } from '../utils/errors.js';
import { audit, AuditAction } from '../services/audit.js';
import { logger } from '../utils/logger.js';

const FAIL_OPEN_MAX = 3;
let consecutiveStoreFailures = 0;

/**
 * @param {object} o
 * @param {string} o.name      bucket namespace, e.g. 'auth.redeem'
 * @param {number} o.windowMs  window length
 * @param {number} o.max       hits allowed per window
 * @param {(req:any)=>string} [o.key]  subject selector; defaults to hashed IP
 */
export function rateLimit({ name, windowMs, max, key }) {
    const windowSec = Math.max(1, Math.floor(windowMs / 1000));
    return async function rateLimitMiddleware(req, res, next) {
        const subject = (key ? key(req) : req.clientIpHash) ?? 'anon';
        const bucket = `${name}:${subject}`;
        try {
            const { rows } = await query(
                `INSERT INTO rate_limits (bucket, window_start, hits)
                 VALUES ($1, to_timestamp(floor(extract(epoch FROM now()) / $2) * $2), 1)
                 ON CONFLICT (bucket, window_start)
                 DO UPDATE SET hits = rate_limits.hits + 1
                 RETURNING hits, window_start`,
                [bucket, windowSec],
            );
            consecutiveStoreFailures = 0;
            const { hits, window_start: windowStart } = rows[0];
            const resetAt = new Date(new Date(windowStart).getTime() + windowSec * 1000);
            const remaining = Math.max(0, max - hits);
            res.setHeader('RateLimit-Limit', String(max));
            res.setHeader('RateLimit-Remaining', String(remaining));
            res.setHeader('RateLimit-Reset', String(Math.max(1, Math.ceil((resetAt - Date.now()) / 1000))));

            if (hits > max) {
                const retryAfter = Math.max(1, Math.ceil((resetAt - Date.now()) / 1000));
                res.setHeader('Retry-After', String(retryAfter));
                // Log the first few over-limit hits, then only every 25th, so a
                // flood cannot be used to hammer the audit table itself.
                if (hits <= max + 3 || hits % 25 === 0) {
                    await audit({
                        action: AuditAction.RATE_LIMITED,
                        severity: hits > max * 5 ? 'alert' : 'warn',
                        ipHash: req.clientIpHash,
                        requestId: req.id,
                        discordUserId: req.user?.discord_id ?? null,
                        metadata: { bucket: name, hits, limit: max, path: req.path },
                    });
                }
                return next(Errors.rateLimited(retryAfter));
            }
            return next();
        } catch (err) {
            // The limiter must not become a denial-of-service on itself. Allow a
            // few requests through while the store is unreachable, then refuse.
            consecutiveStoreFailures += 1;
            logger.error('ratelimit.store_failed', { bucket: name, err: err.message, consecutive: consecutiveStoreFailures });
            if (consecutiveStoreFailures > FAIL_OPEN_MAX) return next(Errors.internal({ reason: 'ratelimit_store' }));
            return next();
        }
    };
}

/** Periodically drop expired windows. Cheap, and keeps the table tiny. */
export function startRateLimitJanitor(intervalMs = 10 * 60 * 1000) {
    const timer = setInterval(async () => {
        try {
            await query("DELETE FROM rate_limits WHERE window_start < now() - interval '2 hours'");
            await query("DELETE FROM script_grants WHERE expires_at < now() - interval '1 hour'");
            await query("DELETE FROM sessions WHERE expires_at < now() - interval '7 days'");
            await query(
                `UPDATE license_keys SET status = 'expired'
                  WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at < now()`,
            );
        } catch (err) {
            logger.error('janitor.failed', { err: err.message });
        }
    }, intervalMs);
    timer.unref();
    return timer;
}

// Named limit profiles used by the routes. Tight by default; the admin surface
// is the tightest because it is the highest-value target.
export const limits = {
    status:       { name: 'status',        windowMs: 60_000,  max: 120 },
    session:      { name: 'auth.session',  windowMs: 60_000,  max: 30 },
    redeem:       { name: 'auth.redeem',   windowMs: 600_000, max: 8 },
    validate:     { name: 'auth.validate', windowMs: 60_000,  max: 30 },
    loaderAuth:   { name: 'loader.auth',   windowMs: 60_000,  max: 12 },
    loaderFetch:  { name: 'loader.fetch',  windowMs: 60_000,  max: 12 },
    scriptLoader: { name: 'script.loader', windowMs: 60_000,  max: 30 },
    admin:        { name: 'admin',         windowMs: 60_000,  max: 20 },
    adminMass:    { name: 'admin.mass',    windowMs: 3_600_000, max: 5 },
};
