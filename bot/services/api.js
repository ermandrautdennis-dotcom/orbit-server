// HTTP client for the backend.
//
// Two separate credentials, held only in this process and never logged, echoed
// into a Discord message, or included in an error shown to a user:
//
//   * BOT_API_SECRET   — the user surface the panel buttons drive. Carries the
//                        Discord id of the interacting user, which Discord has
//                        already authenticated for us.
//   * ADMIN_API_SECRET — key generation, whitelist/blacklist, the kill switch.
//
// Keeping them apart means a bug in the panel handlers cannot reach an
// administrative endpoint even if an attacker controls the arguments.
import { config } from '../../backend/src/config/env.js';

const TIMEOUT_MS = 10_000;

export class AdminApiError extends Error {
    constructor(status, code, message) {
        super(message ?? code ?? `HTTP ${status}`);
        this.status = status;
        this.code = code;
    }
}

async function request(method, url, headers, body) {
    let res;
    try {
        res = await fetch(url, {
            method,
            headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...headers },
            body: body ? JSON.stringify(body) : undefined,
            signal: AbortSignal.timeout(TIMEOUT_MS),
        });
    } catch (err) {
        throw new AdminApiError(0, 'unreachable', `API unreachable: ${err.name}`);
    }

    const text = await res.text();
    let json = null;
    try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON body */ }

    if (!res.ok) throw new AdminApiError(res.status, json?.error ?? 'error', json?.message ?? 'Request failed.');
    return json;
}

/** Administrative call: ADMIN_API_SECRET + the operator's Discord id. */
function call(method, path, { body = null, actorId = null, query = null } = {}) {
    const url = new URL(`${config.apiBaseUrl}/api/admin${path}`);
    if (query) for (const [k, v] of Object.entries(query)) if (v != null) url.searchParams.set(k, String(v));
    return request(method, url, {
        'x-admin-secret': config.secrets.adminApiSecret ?? '',
        ...(actorId ? { 'x-admin-actor': actorId } : {}),
    }, body);
}

/**
 * User-surface call made on behalf of an interacting Discord user. The id and
 * username come from the interaction object the gateway delivered, not from
 * anything the user typed, so they cannot assert someone else's identity.
 */
function userCall(method, path, { user, body = null } = {}) {
    const url = new URL(`${config.apiBaseUrl}/api/bot${path}`);
    return request(method, url, {
        'x-bot-secret': config.secrets.botApiSecret ?? '',
        'x-discord-user': user.id,
        // Base64url so a non-ASCII display name cannot break header encoding or
        // smuggle a newline into the request.
        'x-discord-username': Buffer.from(
            String(user.globalName ?? user.username ?? 'unknown').slice(0, 64), 'utf8',
        ).toString('base64url'),
    }, body);
}

export const userApi = {
    me: (user) => userCall('GET', '/me', { user }),
    redeem: (user, key) => userCall('POST', '/redeem', { user, body: { key } }),
    session: (user) => userCall('POST', '/session', { user }),
    validate: (user, tier) => userCall('POST', '/validate', { user, body: tier ? { tier } : {} }),

    /**
     * Get the loader. The backend requires a live session; when it has lapsed it
     * answers 409 session_required, so one session is established and the call is
     * retried exactly once. Bounded on purpose — a second 409 is a real failure,
     * not something to loop on.
     */
    async getScript(user, tier) {
        try {
            return await userCall('POST', '/script', { user, body: { tier } });
        } catch (err) {
            if (!(err instanceof AdminApiError) || err.code !== 'session_required') throw err;
            await userCall('POST', '/session', { user });
            return userCall('POST', '/script', { user, body: { tier } });
        }
    },
};

export const api = {
    generateKey: (actorId, body) => call('POST', '/keys/generate', { body, actorId }),
    generateMassKeys: (actorId, body) => call('POST', '/keys/generate-mass', { body, actorId }),
    revokeKey: (actorId, body) => call('POST', '/keys/revoke', { body, actorId }),
    keyStats: (actorId) => call('GET', '/keys/stats', { actorId }),
    whitelist: (actorId, body) => call('POST', '/users/whitelist', { body, actorId }),
    unwhitelist: (actorId, body) => call('POST', '/users/unwhitelist', { body, actorId }),
    blacklist: (actorId, body) => call('POST', '/users/blacklist', { body, actorId }),
    unblacklist: (actorId, body) => call('POST', '/users/unblacklist', { body, actorId }),
    user: (actorId, discordId) => call('GET', `/users/${encodeURIComponent(discordId)}`, { actorId }),
    scriptOffline: (actorId, body) => call('POST', '/script/offline', { body, actorId }),
    scriptOnline: (actorId, body) => call('POST', '/script/online', { body, actorId }),
    scriptStatus: (actorId) => call('GET', '/script/status', { actorId }),
    // The unauthenticated status endpoint, for the panel's public status button.
    publicStatus: () => request('GET', new URL(`${config.apiBaseUrl}/api/status`), {}, null),
};
