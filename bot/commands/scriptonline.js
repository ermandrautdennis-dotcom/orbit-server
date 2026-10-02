import { SlashCommandBuilder } from 'discord.js';
import { api, AdminApiError } from '../services/api.js';
import { assertAdmin } from '../utils/permissions.js';
import { embed, ephemeral, describeApiError } from '../utils/reply.js';

export const data = new SlashCommandBuilder()
    .setName('scriptonline')
    .setDescription('Re-enable the script so valid keys can authenticate again.')
    .setDMPermission(false)
    .addStringOption((o) => o.setName('scope').setDescription('Leave empty to bring everything online')
        .addChoices({ name: 'public only', value: 'public' }, { name: 'private only', value: 'private' }))
    .addStringOption((o) => o.setName('reason').setDescription('Audit note').setMaxLength(200));

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    await interaction.deferReply({ ephemeral: true });

    const slug = interaction.options.getString('scope') ?? undefined;
    const reason = interaction.options.getString('reason') ?? undefined;

    try {
        const res = await api.scriptOnline(interaction.user.id, { ...(slug ? { slug } : {}), reason });
        await ephemeral(interaction, {
            embeds: [embed('ok', 'Script online', `Scope: **${res.scope}**. Valid keys can authenticate again.`)],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await ephemeral(interaction, { embeds: [embed('bad', 'Failed', describeApiError(err))] });
    }
}
