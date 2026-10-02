// Public-facing error vocabulary. Handlers throw these; the error middleware
// turns them into a response that carries a stable code and a deliberately
// vague message. Anything that is *not* an ApiError becomes a flat 500 with no
// detail, so an unexpected throw can never leak a stack trace or a SQL string.

export class ApiError extends Error {
    constructor(status, code, message, { meta = null, logLevel = 'warn' } = {}) {
        super(message);
        this.name = 'ApiError';
        this.status = status;
        this.code = code;
        this.publicMessage = message;
        this.meta = meta;
        this.logLevel = logLevel;
        this.expose = true;
    }
}

// Generic messages on purpose: an attacker must not be able to distinguish
// "no such key" from "key already used" from "key expired".
export const Errors = {
    badRequest: (meta) => new ApiError(400, 'invalid_request', 'Invalid request.', { meta }),
    unauthorized: (meta) => new ApiError(401, 'unauthorized', 'Authentication failed.', { meta }),
    forbidden: (meta) => new ApiError(403, 'forbidden', 'Access denied.', { meta }),
    notFound: () => new ApiError(404, 'not_found', 'Not found.'),
    conflict: (meta) => new ApiError(409, 'conflict', 'Request could not be completed.', { meta }),
    // The caller has no live session. The bot answers this by establishing one
    // and retrying once; it is not a permission failure.
    sessionRequired: () => new ApiError(409, 'session_required', 'Authentication required.'),
    tooLarge: () => new ApiError(413, 'payload_too_large', 'Invalid request.'),
    rateLimited: (retryAfter) => {
        const e = new ApiError(429, 'rate_limited', 'Too many requests. Slow down.');
        e.retryAfter = retryAfter;
        return e;
    },
    scriptOffline: () => new ApiError(503, 'script_offline', 'Script is currently offline.'),
    internal: (meta) => new ApiError(500, 'internal_error', 'Something went wrong.', { meta, logLevel: 'error' }),
};
