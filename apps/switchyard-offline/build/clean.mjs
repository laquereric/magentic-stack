#!/usr/bin/env node
// build/clean.mjs — remove generated artifacts

import { rmSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const targets = [
  join(root, 'dist'),
  join(root, 'shared', 'generated-cid.js'),
];

for (const t of targets) {
  if (existsSync(t)) {
    rmSync(t, { recursive: true, force: true });
    console.log(`clean: removed ${t}`);
  }
}
console.log('clean: done');
