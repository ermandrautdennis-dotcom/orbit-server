#!/usr/bin/env node
// Upload a Lua file as the protected source for a tier.
//
//   node scripts/seed-script.js public  ./my-script.lua
//   node scripts/seed-script.js private ./hub.lua
//
// Writes straight to the database using DATABASE_URL, so it works from a local
// shell or from `railway run`. The stored version becomes a content hash, which
// is what the loader reports — so you cannot forget to bump a version number.
import fs from 'node:fs/promises';
import { assertConfig } from '../backend/src/config/env.js';
import { closePool } from '../backend/src/database/pool.js';
import * as scriptSvc from '../backend/src/services/scripts.js';

const [slug, file] = process.argv.slice(2);

if (!['public', 'private'].includes(slug) || !file) {
    process.stderr.write('usage: node scripts/seed-script.js <public|private> <path-to.lua>\n');
    process.exit(2);
}

try {
    assertConfig();
    const source = await fs.readFile(file, 'utf8');
    if (!source.trim()) throw new Error('file is empty');
    if (source.length > 2_000_000) throw new Error('file is larger than 2 MB');

    const updated = await scriptSvc.setSource(slug, source);
    if (!updated) throw new Error(`no script row with slug "${slug}" — run: npm run migrate`);

    process.stdout.write(`uploaded ${slug}: ${Number(updated.bytes)} bytes, version ${updated.version}\n`);
    process.stdout.write('the script is still governed by the online/offline switch — run /scriptonline when ready\n');
} catch (err) {
    process.stderr.write(`seed failed: ${err.message}\n`);
    process.exitCode = 1;
} finally {
    await closePool();
}
