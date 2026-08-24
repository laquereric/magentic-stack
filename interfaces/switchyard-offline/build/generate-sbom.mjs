#!/usr/bin/env node
// build/generate-sbom.mjs — minimal CycloneDX SBOM (no external deps)

import { writeFileSync, mkdirSync, readdirSync, statSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'dist');
mkdirSync(outDir, { recursive: true });

function walk(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    if (name === 'node_modules' || name === '.git' || name === 'dist') continue;
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, acc);
    else acc.push(p);
  }
  return acc;
}

const files = walk(root).filter((f) => !f.endsWith('.zip'));
const components = files.map((f) => {
  const buf = readFileSync(f);
  const hash = createHash('sha256').update(buf).digest('hex');
  return {
    type: 'file',
    name: relative(root, f).replace(/\\/g, '/'),
    hashes: [{ alg: 'SHA-256', content: hash }],
  };
});

const sbom = {
  bomFormat: 'CycloneDX',
  specVersion: '1.5',
  version: 1,
  metadata: {
    timestamp: new Date().toISOString(),
    component: {
      type: 'application',
      name: 'SwitchYard.offline',
      version: '0.1.0',
    },
  },
  components,
};

const out = join(outDir, 'SBOM.cdx.json');
writeFileSync(out, JSON.stringify(sbom, null, 2));
console.log(`generate-sbom: ${components.length} components → ${out}`);
