import { SlashCommandBuilder } from 'discord.js';
import { api, AdminApiError } from '../services/api.js';
import { assertAdmin } from '../utils/permissions.js';
import { embed, ephemeral, describeApiError } from '../utils/reply.js';

export const data = new SlashCommandBuilder()
    .setName('genkey')
    .setDescription('Generate one license key.')
    .setDMPermission(false)
    .addStringOption((o) => o.setName('tier').setDescription('Access tier')
        .addChoices({ name: 'public', value: 'public' }, { name: 'private', value: 'private' }))
    .addIntegerOption((o) => o.setName('days').setDescription('Validity in days (0 = never expires)').setMinValue(0).setMaxValue(3650))
    .addStringOption((o) => o.setName('note').setDescription('Audit note, e.g. who it is for').setMaxLength(200));

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    // Ephemeral from the start: the plaintext key is in this reply and must not
    // land in a channel transcript.
    await interaction.deferReply({ ephemeral: true });

    const tier = interaction.options.getString('tier') ?? 'public';
    const days = interaction.options.getInteger('days');
    const note = interaction.options.getString('note') ?? undefined;

    try {
        const res = await api.generateKey(interaction.user.id, {
            tier,
            ...(days === null ? {} : { ttl_days: days }),
            note,
        });
        await ephemeral(interaction, {
            embeds: [embed('ok', 'License key generated',
                `\`\`\`\n${res.key}\n\`\`\`\nThis is the only time the key is shown. It is stored as a keyed hash and cannot be recovered.`,
                [
                    { name: 'Tier', value: res.tier, inline: true },
                    { name: 'Expires', value: res.expires_at ? `<t:${Math.floor(new Date(res.expires_at).getTime() / 1000)}:R>` : 'never', inline: true },
                    { name: 'Prefix', value: `\`${res.key_prefix}\``, inline: true },
                ])],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await ephemeral(interaction, { embeds: [embed('bad', 'Failed', describeApiError(err))] });
    }
}
