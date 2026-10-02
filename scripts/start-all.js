#!/usr/bin/env node
// Convenience launcher that runs the API and the bot in one container.
//
// Running them as two Railway services is the better default — they scale and
// fail independently, and only the bot needs the Discord token. Use this when
// you would rather pay for one service: if either child exits, the whole process
// exits so the platform restarts both together.
import { spawn } from 'node:child_process';
import process from 'node:process';

const children = [];

function run(name, args) {
    const child = spawn(process.execPath, args, { stdio: 'inherit', env: process.env });
    child.on('exit', (code, signal) => {
        process.stderr.write(`[start-all] ${name} exited (code=${code} signal=${signal})\n`);
        for (const c of children) if (c !== child) c.kill('SIGTERM');
        process.exit(code ?? 1);
    });
    children.push(child);
    return child;
}

run('api', ['backend/src/server.js']);
if (process.env.DISCORD_BOT_TOKEN) run('bot', ['bot/index.js']);
else process.stderr.write('[start-all] DISCORD_BOT_TOKEN not set — starting API only\n');

for (const sig of ['SIGTERM', 'SIGINT']) {
    process.on(sig, () => { for (const c of children) c.kill(sig); });
}
