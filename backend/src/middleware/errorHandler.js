// Terminal error handling. Known ApiErrors become their declared status and a
// fixed public message; everything else becomes a bare 500. No stack trace,
// driver message, SQL fragment or config value ever crosses this boundary.
import { ApiError, Errors } from '../utils/errors.js';
import { logger } from '../utils/logger.js';

export function notFoundHandler(req, _res, next) {
    next(Errors.notFound());
}

export function errorHandler(err, req, res, _next) {
    const apiErr = err instanceof ApiError ? err : null;
    const status = apiErr?.status ?? 500;

    const level = apiErr?.logLevel ?? 'error';
    logger[level]('http.error', {
        requestId: req.id,
        path: req.path,
        method: req.method,
        status,
        code: apiErr?.code ?? 'internal_error',
        // Internal detail: logged, never sent.
        detail: apiErr ? apiErr.meta : { message: err?.message, stack: err?.stack?.split('\n').slice(0, 4) },
        ipHash: req.clientIpHash,
    });

    if (apiErr?.retryAfter) res.setHeader('Retry-After', String(apiErr.retryAfter));
    res.status(status).json({
        ok: false,
        error: apiErr?.code ?? 'internal_error',
        message: apiErr?.publicMessage ?? 'Something went wrong.',
        request_id: req.id,
    });
}

/** Wraps an async handler so a rejected promise reaches the error middleware. */
export const asyncRoute = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
