import { SlashCommandBuilder } from 'discord.js';
import { api, AdminApiError } from '../services/api.js';
import { assertAdmin } from '../utils/permissions.js';
import { embed, ephemeral, describeApiError } from '../utils/reply.js';

export const data = new SlashCommandBuilder()
    .setName('blacklist')
    .setDescription('Blacklist a user: revokes their licenses, script keys and active sessions immediately.')
    .setDMPermission(false)
    .addUserOption((o) => o.setName('user').setDescription('User to blacklist').setRequired(true))
    .addStringOption((o) => o.setName('reason').setDescription('Audit note').setMaxLength(200))
    .addBooleanOption((o) => o.setName('remove').setDescription('Lift the blacklist instead'));

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    await interaction.deferReply({ ephemeral: true });

    const target = interaction.options.getUser('user', true);
    const reason = interaction.options.getString('reason') ?? undefined;
    const remove = interaction.options.getBoolean('remove') ?? false;

    try {
        if (remove) {
            await api.unblacklist(interaction.user.id, { discord_id: target.id, reason });
            await ephemeral(interaction, {
                embeds: [embed('warn', 'Blacklist lifted',
                    `<@${target.id}> can authenticate again.\nLicenses revoked by the blacklist stay revoked — issue a new key with \`/genkey\`.`)],
            });
            return;
        }
        const res = await api.blacklist(interaction.user.id, { discord_id: target.id, reason });
        await ephemeral(interaction, {
            embeds: [embed('bad', 'Blacklisted', `<@${target.id}> (\`${target.id}\`)`, [
                { name: 'Licenses revoked', value: String(res.revoked_licenses), inline: true },
                { name: 'Sessions', value: 'all revoked', inline: true },
                { name: 'Script keys', value: 'all revoked', inline: true },
            ])],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await ephemeral(interaction, { embeds: [embed('bad', 'Failed', describeApiError(err))] });
    }
}
