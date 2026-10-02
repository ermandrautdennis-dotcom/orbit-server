// Unauthenticated status surface. Deliberately thin: it reports whether the
// service is up and whether the script is online, and nothing about licenses,
// users or versions that are not already public.
import { Router } from 'express';
import { asyncRoute } from '../middleware/errorHandler.js';
import { rateLimit, limits } from '../middleware/rateLimit.js';
import * as scriptSvc from '../services/scripts.js';
import { query } from '../database/pool.js';

export const statusRouter = Router();

statusRouter.get('/status', rateLimit(limits.status), asyncRoute(async (_req, res) => {
    const [global, scripts] = await Promise.all([scriptSvc.globalStatus(), scriptSvc.listPublicMeta()]);
    res.json({
        ok: true,
        script_status: global,
        scripts: scripts.map((s) => ({
            slug: s.slug,
            name: s.name,
            version: s.version,
            // Effective status folds in the global switch so a client never has
            // to combine the two itself and get it wrong.
            status: global === 'online' ? s.status : 'offline',
        })),
    });
}));

// Liveness + readiness in one endpoint, as Railway's healthcheck expects.
// Returns 200 only when the database answers; never reveals connection details.
export const healthRouter = Router();
healthRouter.get('/health', asyncRoute(async (_req, res) => {
    try {
        await query('SELECT 1');
        res.json({ status: 'ok' });
    } catch {
        res.status(503).json({ status: 'degraded' });
    }
}));
