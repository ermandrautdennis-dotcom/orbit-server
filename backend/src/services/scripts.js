// Script catalogue and the global kill switch.
//
// Two independent gates must both be open before any source is served:
//   * the global switch (`settings.global_script_status`), flipped by
//     /scriptoffline and /scriptonline, and
//   * the per-script status row.
// Both are read on every loader request, so turning the script off takes effect
// for users who already hold valid keys and valid grants — which is the point.
import crypto from 'node:crypto';
import { query } from '../database/pool.js';

export async function globalStatus() {
    const { rows } = await query("SELECT value FROM settings WHERE key = 'global_script_status'");
    const v = rows[0]?.value;
    return v === 'online' ? 'online' : 'offline';
}

export async function setGlobalStatus(status, actor = null) {
    if (status !== 'online' && status !== 'offline') throw new Error('invalid status');
    await query(
        `INSERT INTO settings (key, value, updated_by, updated_at)
         VALUES ('global_script_status', $1::jsonb, $2, now())
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()`,
        [JSON.stringify(status), actor],
    );
    if (status === 'offline') {
        // Burn every outstanding grant so an in-flight loader cannot still pull
        // the source a second after the switch was thrown.
        await query('UPDATE script_grants SET consumed_at = now() WHERE consumed_at IS NULL');
    }
    return status;
}

export async function setScriptStatus(slug, status) {
    const { rows } = await query(
        `UPDATE scripts SET status = $2, updated_at = now() WHERE slug = $1 RETURNING slug, name, status, version`,
        [slug, status],
    );
    if (status === 'offline' && rows[0]) {
        await query(
            `UPDATE script_grants SET consumed_at = now()
              WHERE consumed_at IS NULL AND script_id = (SELECT id FROM scripts WHERE slug = $1)`,
            [slug],
        );
    }
    return rows[0] ?? null;
}

export async function bySlug(slug) {
    const { rows } = await query(
        `SELECT id, slug, name, version, status, public_script, private_script, updated_at
           FROM scripts WHERE slug = $1`,
        [slug],
    );
    return rows[0] ?? null;
}

export async function sourceBySlug(slug) {
    const { rows } = await query('SELECT id, slug, version, source, status FROM scripts WHERE slug = $1', [slug]);
    return rows[0] ?? null;
}

export async function listPublicMeta() {
    const { rows } = await query(
        `SELECT slug, name, version, status, public_script, private_script, updated_at
           FROM scripts ORDER BY slug`,
    );
    return rows;
}

export async function setSource(slug, source) {
    const { rows } = await query(
        `UPDATE scripts SET source = $2, version = $3, updated_at = now(), name = COALESCE($4, name)
          WHERE slug = $1 RETURNING slug, version, length(source) AS bytes`,
        [slug, source, versionFor(source), null],
    );
    return rows[0] ?? null;
}

/** Content-addressed version so the loader can detect a changed script. */
export function versionFor(source) {
    return crypto.createHash('sha256').update(source).digest('hex').slice(0, 12);
}

/**
 * Is `slug` servable right now? Returns a reason instead of throwing so the
 * caller can log the detail while answering with the generic offline message.
 */
export async function servable(slug) {
    const [global, script] = await Promise.all([globalStatus(), bySlug(slug)]);
    if (global !== 'online') return { ok: false, reason: 'global_offline' };
    if (!script) return { ok: false, reason: 'no_script' };
    if (script.status !== 'online') return { ok: false, reason: 'script_offline' };
    if (slug === 'public' && !script.public_script) return { ok: false, reason: 'tier_disabled' };
    if (slug === 'private' && !script.private_script) return { ok: false, reason: 'tier_disabled' };
    return { ok: true, script };
}
