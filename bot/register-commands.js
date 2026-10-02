#!/usr/bin/env node
// Register slash commands. Guild-scoped when DISCORD_GUILD_ID is set (updates
// are instant and the commands stay off unrelated servers), global otherwise.
import { REST, Routes } from 'discord.js';
import { config } from '../backend/src/config/env.js';
import { loadCommands } from './loadCommands.js';

if (!config.discord.botToken) {
    process.stderr.write('DISCORD_BOT_TOKEN is not set\n');
    process.exit(1);
}
if (!config.discord.clientId) {
    process.stderr.write('DISCORD_CLIENT_ID is not set\n');
    process.exit(1);
}

const commands = await loadCommands();
const body = [...commands.values()].map((c) => c.data.toJSON());
const rest = new REST({ version: '10' }).setToken(config.discord.botToken);

try {
    const route = config.discord.guildId
        ? Routes.applicationGuildCommands(config.discord.clientId, config.discord.guildId)
        : Routes.applicationCommands(config.discord.clientId);
    const res = await rest.put(route, { body });
    process.stdout.write(`registered ${res.length} commands ${config.discord.guildId ? `to guild ${config.discord.guildId}` : 'globally'}\n`);
    for (const c of body) process.stdout.write(`  /${c.name}\n`);
} catch (err) {
    process.stderr.write(`registration failed: ${err.message}\n`);
    process.exit(1);
}
