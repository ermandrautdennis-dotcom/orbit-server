#!/usr/bin/env node
// Print a fresh set of secrets. Each is 32 bytes from the OS CSPRNG, base64url
// encoded. Paste them into .env locally or into the Railway service variables.
//
// Output goes to stdout only — nothing is written to disk, so a stray file
// cannot leak them. Do not pipe this into a file you then commit.
import crypto from 'node:crypto';

const NAMES = ['KEY_PEPPER', 'TOKEN_PEPPER', 'IP_HASH_PEPPER', 'ADMIN_API_SECRET', 'BOT_API_SECRET'];

const lines = NAMES.map((n) => `${n}=${crypto.randomBytes(32).toString('base64url')}`);

process.stdout.write(`${lines.join('\n')}\n`);
process.stderr.write([
    '',
    '# Each value above is 32 bytes of CSPRNG output.',
    '# KEY_PEPPER   — rotating it invalidates every existing license key. Back it up.',
    '# TOKEN_PEPPER — rotating it signs out every session and burns every script key.',
    '# ADMIN_API_SECRET / BOT_API_SECRET — must match between the API service and the',
    '#                bot service. Keep them different from each other.',
    '',
].join('\n'));
