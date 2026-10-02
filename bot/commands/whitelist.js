import { SlashCommandBuilder } from 'discord.js';
import { api, AdminApiError } from '../services/api.js';
import { assertAdmin } from '../utils/permissions.js';
import { embed, ephemeral, describeApiError } from '../utils/reply.js';

export const data = new SlashCommandBuilder()
    .setName('whitelist')
    .setDescription('Whitelist a Discord user (required for private hub access).')
    .setDMPermission(false)
    .addUserOption((o) => o.setName('user').setDescription('User to whitelist').setRequired(true))
    .addStringOption((o) => o.setName('reason').setDescription('Audit note').setMaxLength(200))
    .addBooleanOption((o) => o.setName('remove').setDescription('Remove the whitelist instead of adding it'));

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    await interaction.deferReply({ ephemeral: true });

    const target = interaction.options.getUser('user', true);
    const reason = interaction.options.getString('reason') ?? undefined;
    const remove = interaction.options.getBoolean('remove') ?? false;

    try {
        const fn = remove ? api.unwhitelist : api.whitelist;
        const res = await fn(interaction.user.id, { discord_id: target.id, reason });
        await ephemeral(interaction, {
            embeds: [embed(remove ? 'warn' : 'ok',
                remove ? 'Whitelist removed' : 'Whitelisted',
                `<@${target.id}> (\`${target.id}\`)`,
                [{ name: 'Whitelisted', value: String(res.whitelisted), inline: true }])],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await ephemeral(interaction, { embeds: [embed('bad', 'Failed', describeApiError(err))] });
    }
}
