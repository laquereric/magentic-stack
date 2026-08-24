// tests/manifest.test.mjs — source + dist MV3 policy gates

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

function loadManifest(rel) {
  const p = join(root, rel);
  assert.ok(existsSync(p), `missing ${rel}`);
  return JSON.parse(readFileSync(p, 'utf8'));
}

function assertPolicy(m, label) {
  assert.equal(m.manifest_version, 3, `${label}: mv3`);
  assert.deepEqual(m.permissions, ['storage'], `${label}: storage only`);
  assert.ok(!m.content_scripts || m.content_scripts.length === 0, `${label}: no content_scripts`);
  assert.equal(m.host_permissions.length, 3, `${label}: 3 hosts`);
  for (const h of m.host_permissions) {
    assert.match(h, /^https:\/\/(api\.openai\.com|api\.anthropic\.com|integrate\.api\.nvidia\.com)\/\*$/);
  }
  assert.ok(m.content_security_policy?.extension_pages, `${label}: CSP present`);
  assert.match(m.content_security_policy.extension_pages, /default-src 'self'/);
  assert.equal(m.background?.type, 'module');
  assert.equal(m.background?.service_worker, 'service-worker.js');
}

describe('chrome/manifest.json source policy', () => {
  it('is narrow MV3', () => {
    assertPolicy(loadManifest('chrome/manifest.json'), 'source');
  });
});

describe('check-manifest.mjs gate', () => {
  it('exits 0 on source/dist manifest', () => {
    const r = spawnSync(process.execPath, [join(root, 'build', 'check-manifest.mjs')], {
      encoding: 'utf8',
    });
    assert.equal(r.status, 0, r.stderr || r.stdout);
    assert.match(r.stdout || '', /check-manifest ok/);
  });
});

describe('dist/chrome after build (if present)', () => {
  it('matches policy when built', () => {
    const distMan = join(root, 'dist', 'chrome', 'manifest.json');
    if (!existsSync(distMan)) {
      // build not required for unit path — skip softly
      return;
    }
    assertPolicy(JSON.parse(readFileSync(distMan, 'utf8')), 'dist');
  });
});
