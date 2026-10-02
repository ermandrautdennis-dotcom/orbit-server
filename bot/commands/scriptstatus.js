import { SlashCommandBuilder } from 'discord.js';
import { api, AdminApiError } from '../services/api.js';
import { assertAdmin } from '../utils/permissions.js';
import { embed, ephemeral, describeApiError } from '../utils/reply.js';

export const data = new SlashCommandBuilder()
    .setName('scriptstatus')
    .setDescription('Show whether the script is online or offline.')
    .setDMPermission(false);

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    await interaction.deferReply({ ephemeral: true });

    try {
        const [status, stats] = await Promise.all([
            api.scriptStatus(interaction.user.id),
            api.keyStats(interaction.user.id).catch(() => null),
        ]);
        const online = status.global_status === 'online';
        const fields = status.scripts.map((s) => ({
            name: `${s.name} (${s.slug})`,
            value: `${s.effective === 'online' ? '🟢 online' : '🔴 offline'} · v\`${s.version}\``,
            inline: true,
        }));
        if (stats?.stats?.length) {
            const active = stats.stats.filter((r) => r.status === 'active').reduce((a, r) => a + r.n, 0);
            const unused = stats.stats.filter((r) => r.status === 'unused').reduce((a, r) => a + r.n, 0);
            const revoked = stats.stats.filter((r) => r.status === 'revoked').reduce((a, r) => a + r.n, 0);
            fields.push({ name: 'Licenses', value: `active **${active}** · unused **${unused}** · revoked **${revoked}**` });
        }
        await ephemeral(interaction, {
            embeds: [embed(online ? 'ok' : 'bad',
                `Global switch: ${online ? 'ONLINE' : 'OFFLINE'}`,
                online ? null : 'No script is being served while the global switch is off.',
                fields)],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await ephemeral(interaction, { embeds: [embed('bad', 'Failed', describeApiError(err))] });
    }
}
