#!/usr/bin/env node
// build/package.mjs — zip dist/chrome + SHA256SUMS

import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const chromeDir = join(root, 'dist', 'chrome');
if (!existsSync(chromeDir)) {
  console.error('package: run build first (dist/chrome missing)');
  process.exit(1);
}

// Ensure SBOM
spawnSync(process.execPath, [join(root, 'build', 'generate-sbom.mjs')], { stdio: 'inherit' });

const zipPath = join(root, 'dist', 'SwitchYard.offline-V1-chrome.zip');
const zip = spawnSync('zip', ['-r', '-q', zipPath, '.'], { cwd: chromeDir, stdio: 'inherit' });
if (zip.status !== 0) {
  // fallback: no zip binary — write a note and still produce sums
  console.warn('package: zip CLI failed or missing; skipping zip archive');
}

function walk(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, acc);
    else acc.push(p);
  }
  return acc;
}

const files = walk(join(root, 'dist'));
const lines = [];
for (const f of files.sort()) {
  const hash = createHash('sha256').update(readFileSync(f)).digest('hex');
  lines.push(`${hash}  ${relative(join(root, 'dist'), f).replace(/\\/g, '/')}`);
}
const sumsPath = join(root, 'dist', 'SHA256SUMS');
writeFileSync(sumsPath, lines.join('\n') + '\n');
console.log(`package: SHA256SUMS (${lines.length} files) → ${sumsPath}`);
if (existsSync(zipPath)) console.log(`package: zip → ${zipPath}`);
