// Per-request context: a request id for correlating logs, and the client IP
// resolved once, with its hash precomputed so nothing downstream handles a raw
// address. When TRUST_PROXY is off, X-Forwarded-For is ignored entirely —
// otherwise any client could spoof its own IP and defeat per-IP rate limits.
import crypto from 'node:crypto';
import { config } from '../config/env.js';
import { hashIp } from '../security/crypto.js';

export function requestContext(req, res, next) {
    const incoming = req.get('x-request-id');
    req.id = /^[A-Za-z0-9_-]{8,64}$/.test(incoming ?? '') ? incoming : crypto.randomBytes(12).toString('base64url');
    res.setHeader('X-Request-Id', req.id);

    // express sets req.ip from the trust-proxy setting; fall back to the socket.
    req.clientIp = (config.trustProxy ? req.ip : req.socket.remoteAddress) ?? '0.0.0.0';
    req.clientIpHash = hashIp(req.clientIp);
    req.startedAt = process.hrtime.bigint();
    next();
}

export function accessLog(logger) {
    return (req, res, next) => {
        res.on('finish', () => {
            const ms = Number(process.hrtime.bigint() - req.startedAt) / 1e6;
            logger.info('http.request', {
                requestId: req.id,
                method: req.method,
                // Path only — a query string could carry a key someone pasted.
                path: req.path,
                status: res.statusCode,
                ms: Math.round(ms),
                ipHash: req.clientIpHash,
            });
        });
        next();
    };
}
