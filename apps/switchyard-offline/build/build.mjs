#!/usr/bin/env node
// build/build.mjs — assemble shared/ + chrome/ → dist/chrome

import { cpSync, mkdirSync, rmSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist', 'chrome');

// 1) generate CID
const gen = spawnSync(process.execPath, [join(root, 'build', 'generate-cid.mjs')], {
  stdio: 'inherit',
});
if (gen.status !== 0) process.exit(gen.status || 1);

// 2) clean dist/chrome
rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });

// 3) copy shared core (flat into dist/chrome)
const sharedFiles = [
  'errors.js',
  'routes.js',
  'router.js',
  'egress.js',
  'contract.js',
  'generated-cid.js',
  'cid.template.json',
];
for (const f of sharedFiles) {
  const src = join(root, 'shared', f);
  if (!existsSync(src)) {
    console.error(`build: missing shared/${f}`);
    process.exit(1);
  }
  cpSync(src, join(dist, f));
}

// 4) copy chrome overlay
const chromeFiles = [
  'manifest.json',
  'service-worker.js',
  'credential-store.js',
  'popup.html',
  'popup.js',
  'popup.css',
];
for (const f of chromeFiles) {
  cpSync(join(root, 'chrome', f), join(dist, f));
}

// 5) optional: pin externally_connectable from env
const clientId = process.env.SWITCHYARD_CLIENT_EXTENSION_ID;
if (clientId && /^[a-p]{32}$/.test(clientId)) {
  const manPath = join(dist, 'manifest.json');
  const m = JSON.parse(readFileSync(manPath, 'utf8'));
  m.externally_connectable = { ids: [clientId] };
  writeFileSync(manPath, JSON.stringify(m, null, 2));
  console.log(`build: pinned externally_connectable to ${clientId}`);
}

// 6) check-manifest
const check = spawnSync(process.execPath, [join(root, 'build', 'check-manifest.mjs')], {
  stdio: 'inherit',
});
if (check.status !== 0) process.exit(check.status || 1);

console.log(`build: ok → ${dist}`);
