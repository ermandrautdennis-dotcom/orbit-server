// Express application assembly. Order matters here and is deliberate:
// security headers → proxy trust → body limits → context → CSRF → routes →
// 404 → error handler.
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import { config } from './config/env.js';
import { logger } from './utils/logger.js';
import { requestContext, accessLog } from './middleware/context.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import { Errors } from './utils/errors.js';
import { statusRouter, healthRouter } from './routes/status.js';
import { userRouter } from './routes/user.js';
import { scriptRouter } from './routes/script.js';
import { adminRouter } from './routes/admin.js';

export function createApp() {
    const app = express();

    app.disable('x-powered-by');
    app.set('etag', false);

    // Only trust X-Forwarded-For when explicitly configured, and then only one
    // hop (the platform proxy). Blindly trusting the whole chain would let a
    // client prepend any address it likes and bypass per-IP rate limits.
    app.set('trust proxy', config.trustProxy ? 1 : false);

    // This service renders no HTML and has no browser clients, so the policy is
    // "deny everything": nothing may be loaded, framed or embedded from here.
    app.use(helmet({
        contentSecurityPolicy: {
            useDefaults: false,
            directives: {
                'default-src': ["'none'"],
                'frame-ancestors': ["'none'"],
                'base-uri': ["'none'"],
                'form-action': ["'none'"],
                'sandbox': [],
            },
        },
        crossOriginEmbedderPolicy: false,
        referrerPolicy: { policy: 'no-referrer' },
        hsts: config.isProd ? { maxAge: 31_536_000, includeSubDomains: true, preload: false } : false,
    }));
    app.use(helmet.crossOriginResourcePolicy({ policy: 'same-origin' }));

    // Redirect plain HTTP to HTTPS in production when behind a proxy that tells
    // us the original scheme.
    if (config.isProd) {
        app.use((req, res, next) => {
            const proto = config.trustProxy ? req.get('x-forwarded-proto') : req.protocol;
            if (proto && proto !== 'https' && req.path !== '/health') {
                return res.redirect(308, `${config.publicBaseUrl}${req.originalUrl}`);
            }
            return next();
        });
    }

    // No CORS middleware at all. The clients are the Discord bot (server to
    // server) and the Lua loader (an executor's HTTP stack, which does not
    // enforce CORS). Emitting no Access-Control-Allow-Origin header is the most
    // restrictive possible answer: no browser page on any origin can read a
    // response from this API, and there is no credentialed cross-origin surface
    // to attack. Because no credential is ever carried in a cookie, there is
    // likewise no CSRF surface.
    // Compression is skipped for the protected source. A compressed response
    // whose body holds a secret and whose request the caller can vary is the
    // shape of a compression side-channel (BREACH); the source is small enough
    // that the bandwidth is not worth the class of bug.
    app.use(compression({
        filter(req, res) {
            if (req.path === '/api/script/fetch') return false;
            return compression.filter(req, res);
        },
    }));
    // The admin source upload is the only endpoint that legitimately carries a
    // large body, so it gets its own parser first; everything else is capped
    // hard at 32kb. Oversized payloads are rejected before any handler runs and
    // the parser's error is translated so no internals leak out.
    app.use('/api/admin/script/source', express.json({ limit: '4mb', strict: true }));
    app.use(express.json({ limit: '32kb', strict: true }));
    app.use((err, _req, _res, next) => {
        if (err?.type === 'entity.too.large') return next(Errors.tooLarge());
        if (err instanceof SyntaxError && 'body' in err) return next(Errors.badRequest({ reason: 'bad_json' }));
        return next(err);
    });

    app.use(requestContext);
    app.use(accessLog(logger));

    app.use('/', healthRouter);
    app.use('/api', statusRouter);
    app.use('/api', scriptRouter);
    // The same user-facing handlers under both documented prefixes.
    app.use('/api/auth', userRouter);
    app.use('/api/bot', userRouter);
    app.use('/api/admin', adminRouter);


    app.use(notFoundHandler);
    app.use(errorHandler);
    return app;
}
