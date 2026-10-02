// Authorisation for administrative slash commands.
//
// Two gates, both required to be *passed*, either of which suffices:
//   * the invoking member holds one of DISCORD_ADMIN_ROLE_IDS, or
//   * their user id is in DISCORD_OWNER_IDS (break-glass).
//
// Roles are read from the live member object the gateway supplies, not from
// anything in the interaction payload a client could shape. The backend does not
// rely on this check — it only accepts the admin secret — so a bypass here still
// cannot forge an admin API call without the secret. This is the first gate, not
// the only one.
import { config } from '../../backend/src/config/env.js';

export function isAuthorisedAdmin(interaction) {
    const userId = interaction.user?.id;
    if (!userId) return false;
    if (config.discord.ownerIds.includes(userId)) return true;

    // Must be inside the configured guild: a DM has no roles to check.
    if (!interaction.inGuild()) return false;
    if (config.discord.guildId && interaction.guildId !== config.discord.guildId) return false;

    const roles = interaction.member?.roles;
    const ids = roles?.cache ? [...roles.cache.keys()] : (Array.isArray(roles) ? roles : []);
    return config.discord.adminRoleIds.some((r) => ids.includes(r));
}

/** Replies with a denial and returns false when the caller is not authorised. */
export async function assertAdmin(interaction) {
    if (isAuthorisedAdmin(interaction)) return true;
    await interaction.reply({ content: 'Access denied.', ephemeral: true });
    return false;
}
