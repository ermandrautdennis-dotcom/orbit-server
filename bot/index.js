#!/usr/bin/env node
// Discord bot process. It holds the admin secret and talks to the backend over
// HTTP; it never touches the database directly, so every administrative action
// goes through the same validated, rate-limited, audited API surface as
// everything else.
import { Client, Events, GatewayIntentBits, MessageFlags } from 'discord.js';
import { assertConfig, config } from '../backend/src/config/env.js';
import { logger } from '../backend/src/utils/logger.js';
import { loadCommands } from './loadCommands.js';
import { isAuthorisedAdmin } from './utils/permissions.js';
import { routePanelInteraction } from './interactions/panel.js';

try {
    assertConfig();
} catch (err) {
    process.stderr.write(`${err.message}\n`);
    process.exit(1);
}
if (!config.discord.botToken) {
    process.stderr.write('DISCORD_BOT_TOKEN is not set\n');
    process.exit(1);
}
if (!config.discord.adminRoleIds.length && !config.discord.ownerIds.length) {
    process.stderr.write('Refusing to start: neither DISCORD_ADMIN_ROLE_IDS nor DISCORD_OWNER_IDS is set, so no one could run any command.\n');
    process.exit(1);
}

const commands = await loadCommands();

// Guilds intent only. The bot reads no message content and needs no privileged
// intent — least privilege, and nothing to leak if the token is compromised.
const client = new Client({ intents: [GatewayIntentBits.Guilds] });

// Per-user cooldown in front of every command. The backend rate limits too; this
// keeps obvious spam from ever reaching it.
const cooldowns = new Map();
const COOLDOWN_MS = 2_000;

function onCooldown(userId) {
    const now = Date.now();
    const until = cooldowns.get(userId) ?? 0;
    if (until > now) return true;
    cooldowns.set(userId, now + COOLDOWN_MS);
    if (cooldowns.size > 5_000) {
        for (const [k, v] of cooldowns) if (v < now) cooldowns.delete(k);
    }
    return false;
}

client.once(Events.ClientReady, (c) => {
    logger.info('bot.ready', { tag: c.user.tag, commands: commands.size, guildScoped: Boolean(config.discord.guildId) });
});

client.on(Events.InteractionCreate, async (interaction) => {
    // Panel buttons and the redeem modal. These are the user-facing surface, so
    // they are handled first and are available to everyone — authorisation is the
    // backend's job, per license, not a Discord role check.
    if (interaction.isButton() || interaction.isModalSubmit()) {
        if (onCooldown(interaction.user.id)) {
            await interaction.reply({ content: 'Slow down.', flags: MessageFlags.Ephemeral }).catch(() => {});
            return;
        }
        try {
            const handled = await routePanelInteraction(interaction);
            if (handled) {
                logger.info('bot.panel_interaction', { id: interaction.customId, userId: interaction.user.id });
            }
        } catch (err) {
            logger.error('bot.panel_failed', { id: interaction.customId, err: err.message, stack: err.stack?.split('\n').slice(0, 4) });
            const body = { content: 'Something went wrong.', flags: MessageFlags.Ephemeral };
            if (interaction.deferred || interaction.replied) await interaction.editReply({ content: body.content }).catch(() => {});
            else await interaction.reply(body).catch(() => {});
        }
        return;
    }

    if (!interaction.isChatInputCommand()) return;
    const command = commands.get(interaction.commandName);
    if (!command) return;

    if (onCooldown(interaction.user.id)) {
        await interaction.reply({ content: 'Slow down.', flags: MessageFlags.Ephemeral }).catch(() => {});
        return;
    }

    // Logged for every attempt, authorised or not, so command abuse is visible.
    logger.info('bot.command', {
        command: interaction.commandName,
        userId: interaction.user.id,
        guildId: interaction.guildId,
        authorised: isAuthorisedAdmin(interaction),
    });

    try {
        await command.execute(interaction);
    } catch (err) {
        logger.error('bot.command_failed', { command: interaction.commandName, err: err.message, stack: err.stack?.split('\n').slice(0, 4) });
        const body = { content: 'Something went wrong.', flags: MessageFlags.Ephemeral };
        if (interaction.deferred || interaction.replied) await interaction.editReply({ content: body.content }).catch(() => {});
        else await interaction.reply(body).catch(() => {});
    }
});

client.on(Events.Error, (err) => logger.error('bot.client_error', { err: err.message }));

process.on('SIGTERM', () => { client.destroy(); process.exit(0); });
process.on('SIGINT', () => { client.destroy(); process.exit(0); });

await client.login(config.discord.botToken);
