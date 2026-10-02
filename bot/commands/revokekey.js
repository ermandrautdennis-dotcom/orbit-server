import { SlashCommandBuilder } from 'discord.js';
import { api, AdminApiError } from '../services/api.js';
import { assertAdmin } from '../utils/permissions.js';
import { embed, ephemeral, describeApiError } from '../utils/reply.js';

// Takes the license id rather than the key itself: the plaintext key is not
// recoverable, and /userinfo shows the ids.
export const data = new SlashCommandBuilder()
    .setName('revokekey')
    .setDescription('Revoke a license by its id (see /userinfo). Also burns its script key.')
    .setDMPermission(false)
    .addIntegerOption((o) => o.setName('license_id').setDescription('License id').setRequired(true).setMinValue(1))
    .addStringOption((o) => o.setName('reason').setDescription('Audit note').setMaxLength(200));

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    await interaction.deferReply({ ephemeral: true });

    try {
        const res = await api.revokeKey(interaction.user.id, {
            license_id: interaction.options.getInteger('license_id', true),
            reason: interaction.options.getString('reason') ?? undefined,
        });
        await ephemeral(interaction, {
            embeds: [embed('warn', 'License revoked', `id \`${res.license_id}\` · prefix \`${res.key_prefix}\`\nIts script key is revoked too, so any loader using it fails on the next request.`)],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await ephemeral(interaction, { embeds: [embed('bad', 'Failed', describeApiError(err))] });
    }
}
