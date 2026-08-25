#!/usr/bin/env node
// build/check-manifest.mjs — strict MV3 gate

import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const candidates = [
  join(root, 'dist', 'chrome', 'manifest.json'),
  join(root, 'chrome', 'manifest.json'),
];

const path = candidates.find((p) => existsSync(p));
if (!path) {
  console.error('check-manifest: no manifest.json found');
  process.exit(1);
}

const m = JSON.parse(readFileSync(path, 'utf8'));
const errors = [];

if (m.manifest_version !== 3) errors.push('manifest_version must be 3');

const perms = m.permissions || [];
const forbidden = [
  'tabs',
  'webRequest',
  'webRequestBlocking',
  'debugger',
  'proxy',
  'nativeMessaging',
  'clipboardRead',
  'history',
  'cookies',
  'management',
  '<all_urls>',
];
for (const p of forbidden) {
  if (perms.includes(p)) errors.push(`forbidden permission: ${p}`);
}
if (perms.length !== 1 || perms[0] !== 'storage') {
  errors.push(`permissions must be exactly ["storage"], got ${JSON.stringify(perms)}`);
}

if (m.content_scripts && m.content_scripts.length) {
  errors.push('content_scripts must be absent');
}

const hosts = m.host_permissions || [];
const allowedHosts = new Set([
  'https://api.openai.com/*',
  'https://api.anthropic.com/*',
  'https://integrate.api.nvidia.com/*',
]);
for (const h of hosts) {
  if (!allowedHosts.has(h)) errors.push(`host_permissions not allowlisted: ${h}`);
}
if (hosts.length !== 3) errors.push('host_permissions must list exactly 3 provider origins');

const csp = m.content_security_policy && m.content_security_policy.extension_pages;
if (!csp || typeof csp !== 'string') {
  errors.push('content_security_policy.extension_pages required');
} else {
  if (!csp.includes("default-src 'self'")) errors.push('CSP must include default-src self');
  if (!csp.includes('api.openai.com')) errors.push('CSP connect-src must allow openai');
  if (!csp.includes('api.anthropic.com')) errors.push('CSP connect-src must allow anthropic');
  if (!csp.includes('integrate.api.nvidia.com')) errors.push('CSP connect-src must allow nvidia');
}

if (!m.background || m.background.type !== 'module') {
  errors.push('background.type must be module');
}
if (!m.background || m.background.service_worker !== 'service-worker.js') {
  errors.push('background.service_worker must be service-worker.js');
}

if (errors.length) {
  console.error(`check-manifest FAIL (${path}):`);
  for (const e of errors) console.error(' -', e);
  process.exit(1);
}

console.log(`check-manifest ok: ${path}`);
