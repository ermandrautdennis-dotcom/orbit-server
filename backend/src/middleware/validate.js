// Request validation with zod. Every route that reads a body or a param runs
// through here, and the parsed, stripped output replaces the raw input — so a
// handler can never reach an unvalidated field, and mass-assignment of extra
// keys is impossible because unknown keys are dropped.
import { z } from 'zod';
import { Errors } from '../utils/errors.js';

export function validate({ body, params, query: q }) {
    return (req, _res, next) => {
        try {
            if (body) req.body = body.parse(req.body ?? {});
            if (params) req.params = params.parse(req.params ?? {});
            if (q) req.validatedQuery = q.parse(req.query ?? {});
            next();
        } catch (err) {
            // Field names are safe to surface (they are our own schema); values
            // are not, so only paths and codes go out.
            const issues = (err.issues ?? []).slice(0, 6).map((i) => ({ path: i.path.join('.'), code: i.code }));
            next(Errors.badRequest({ issues }));
        }
    };
}

/** Collapse whitespace and strip control characters from free text. */
const clean = (max) => z.string().trim().max(max).transform((s) => s.replace(/[\u0000-\u001f\u007f]/g, ''));

export const schemas = {
    licenseKey: z.string().min(16).max(40),
    discordId: z.string().regex(/^\d{17,20}$/, 'discord snowflake'),
    scriptSlug: z.enum(['public', 'private']),
    note: clean(200).optional(),
    reason: clean(200).optional(),
    tier: z.enum(['public', 'private']),
    positiveDays: z.number().int().min(0).max(3650),
    opaqueToken: z.string().regex(/^[A-Za-z0-9_-]{20,200}$/),
};

export { z };
