import { ChannelType, PermissionsBitField, SlashCommandBuilder } from 'discord.js';
import { assertAdmin } from '../utils/permissions.js';
import { buildPanel } from '../interactions/panel.js';
import { embed, ephemeral } from '../utils/reply.js';

export const data = new SlashCommandBuilder()
    .setName('genpanel')
    .setDescription('Post the authentication panel into a channel.')
    .setDMPermission(false)
    // Belt and braces: Discord hides the command from non-managers, and
    // assertAdmin() re-checks against the configured roles/owners.
    .setDefaultMemberPermissions(PermissionsBitField.Flags.ManageGuild)
    .addChannelOption((o) => o.setName('channel')
        .setDescription('Where to post it (defaults to here)')
        .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement));

export async function execute(interaction) {
    if (!await assertAdmin(interaction)) return;
    await interaction.deferReply({ ephemeral: true });

    const channel = interaction.options.getChannel('channel') ?? interaction.channel;

    // Check our own permissions before posting so the failure is a clear message
    // rather than an unhandled API error.
    const me = await interaction.guild.members.fetchMe();
    const perms = channel.permissionsFor(me);
    if (!perms?.has(PermissionsBitField.Flags.SendMessages) || !perms?.has(PermissionsBitField.Flags.EmbedLinks)) {
        await ephemeral(interaction, {
            embeds: [embed('bad', 'Cannot post there',
                `I need **Send Messages** and **Embed Links** in <#${channel.id}>.`)],
        });
        return;
    }

    const message = await channel.send(buildPanel());

    await ephemeral(interaction, {
        embeds: [embed('ok', 'Panel posted',
            [
                `Posted in <#${channel.id}>. [Jump to it](${message.url})`,
                '',
                'The panel is stateless: its buttons keep working after restarts and redeploys, so you only need one per server. Pin it.',
            ].join('\n'))],
    });
}
