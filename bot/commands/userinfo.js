import { SlashCommandBuilder } from 'discord.js';
import { api, AdminApiError } from '../services/api.js';
import { assertAdmin } from '../utils/permissions.js';
import { embed, ephemeral, describeApiError } from '../utils/reply.js';

export const data = new SlashCommandBuilder()
    .setName('userinfo')
    .setDescription('Show a user\'s licenses and whitelist/blacklist state.')
    .setDMPermission(false)
    .addUserOption((o) => o.setName('user').setDescription('User to inspect').setRequired(true));

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    await interaction.deferReply({ ephemeral: true });

    const target = interaction.options.getUser('user', true);
    try {
        const res = await api.user(interaction.user.id, target.id);
        const lic = res.licenses.length
            ? res.licenses.map((l) => `\`${l.id}\` · \`${l.key_prefix}\` · ${l.tier} · ${l.status} · uses ${l.usage_count} · ${l.expires_at ? `expires <t:${Math.floor(new Date(l.expires_at).getTime() / 1000)}:R>` : 'no expiry'}`).join('\n')
            : '_none_';
        await ephemeral(interaction, {
            embeds: [embed(res.user.blacklisted ? 'bad' : 'info', res.user.username, `<@${target.id}> (\`${target.id}\`)`, [
                { name: 'Whitelisted', value: String(res.user.whitelisted), inline: true },
                { name: 'Blacklisted', value: String(res.user.blacklisted), inline: true },
                { name: 'Active licenses', value: lic.slice(0, 1000) },
            ])],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await ephemeral(interaction, { embeds: [embed('bad', 'Failed', describeApiError(err))] });
    }
}
