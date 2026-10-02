import { AttachmentBuilder, SlashCommandBuilder } from 'discord.js';
import { config } from '../../backend/src/config/env.js';
import { api, AdminApiError } from '../services/api.js';
import { assertAdmin } from '../utils/permissions.js';
import { embed, ephemeral, describeApiError } from '../utils/reply.js';

// Hard ceiling is enforced by the backend as well (MAX_MASS_KEYS) and by its own
// hourly rate limit on this endpoint; the option bounds here are only the first
// line of defence.
const MAX = Math.min(config.policy.maxMassKeys, 100);

export const data = new SlashCommandBuilder()
    .setName('genmasskey')
    .setDescription(`Generate up to ${MAX} license keys at once.`)
    .setDMPermission(false)
    .addIntegerOption((o) => o.setName('count').setDescription(`How many keys (1-${MAX})`)
        .setRequired(true).setMinValue(1).setMaxValue(MAX))
    .addStringOption((o) => o.setName('tier').setDescription('Access tier')
        .addChoices({ name: 'public', value: 'public' }, { name: 'private', value: 'private' }))
    .addIntegerOption((o) => o.setName('days').setDescription('Validity in days (0 = never expires)').setMinValue(0).setMaxValue(3650))
    .addStringOption((o) => o.setName('note').setDescription('Audit note, e.g. the batch purpose').setMaxLength(200));

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    await interaction.deferReply({ ephemeral: true });

    const count = interaction.options.getInteger('count', true);
    const tier = interaction.options.getString('tier') ?? 'public';
    const days = interaction.options.getInteger('days');
    const note = interaction.options.getString('note') ?? undefined;

    try {
        const res = await api.generateMassKeys(interaction.user.id, {
            count,
            tier,
            ...(days === null ? {} : { ttl_days: days }),
            note,
        });
        // Keys go out as an ephemeral text attachment rather than inline, so a
        // large batch is not pasted into the message history and is easy to file.
        const file = new AttachmentBuilder(
            Buffer.from(`${res.keys.join('\n')}\n`, 'utf8'),
            { name: `keys-${tier}-${new Date().toISOString().slice(0, 10)}.txt` },
        );
        await ephemeral(interaction, {
            embeds: [embed('ok', `${res.count} license keys generated`,
                'Attached as a file, visible only to you. The keys are not recoverable after this message.',
                [
                    { name: 'Tier', value: tier, inline: true },
                    { name: 'Expires', value: res.expires_at ? `<t:${Math.floor(new Date(res.expires_at).getTime() / 1000)}:R>` : 'never', inline: true },
                ])],
            files: [file],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await ephemeral(interaction, { embeds: [embed('bad', 'Failed', describeApiError(err))] });
    }
}
