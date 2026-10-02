// Command discovery. Each file in ./commands exports { data, execute }.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'commands');

export async function loadCommands() {
    const files = (await fs.readdir(dir)).filter((f) => f.endsWith('.js')).sort();
    const commands = new Map();
    for (const file of files) {
        const mod = await import(new URL(`commands/${file}`, import.meta.url));
        if (!mod.data || typeof mod.execute !== 'function') {
            throw new Error(`bot/commands/${file} must export { data, execute }`);
        }
        commands.set(mod.data.name, mod);
    }
    return commands;
}
