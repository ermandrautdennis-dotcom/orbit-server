// Reply helpers. Administrative output is always ephemeral: generated keys, user
// ids and license state should not be left sitting in a channel scrollback.
import { EmbedBuilder } from 'discord.js';

const COLORS = { ok: 0x7c5cff, warn: 0xffb020, bad: 0xff4d6d, info: 0x4f8cff };

export function embed(kind, title, description, fields = []) {
    const e = new EmbedBuilder()
        .setColor(COLORS[kind] ?? COLORS.info)
        .setTitle(title)
        .setTimestamp(new Date());
    if (description) e.setDescription(description);
    if (fields.length) e.addFields(fields.slice(0, 20));
    return e;
}

export async function ephemeral(interaction, payload) {
    const body = { ...payload, ephemeral: true };
    if (interaction.deferred || interaction.replied) return interaction.editReply(payload);
    return interaction.reply(body);
}

/**
 * Translate an AdminApiError into something a human can act on, without
 * surfacing internals. Unknown failures become one generic line.
 */
export function describeApiError(err) {
    switch (err?.code) {
        case 'unreachable': return 'The backend is unreachable. Check API_BASE_URL and that the API is running.';
        case 'forbidden': return 'The backend rejected this request. Check ADMIN_API_SECRET matches on both services.';
        case 'rate_limited': return 'Rate limited by the backend. Try again shortly.';
        case 'not_found': return 'No matching record.';
        case 'invalid_request': return 'Invalid arguments.';
        default: return 'The request failed.';
    }
}
