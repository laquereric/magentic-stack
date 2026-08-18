// local-listener/credentials.mjs — on-device provider keys (env or chmod-600 keys.json).
// NEVER log secret values.

import { existsSync, mkdirSync, readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { randomBytes } from 'node:crypto';

export const PROVIDER_ENV = Object.freeze({
  openai: 'SWITCHYARD_OPENAI_KEY',
  anthropic: 'SWITCHYARD_ANTHROPIC_KEY',
  nvidia: 'SWITCHYARD_NVIDIA_KEY',
});

export function defaultConfigDir(home = homedir()) {
  return join(home, '.switchyard-offline');
}

/** Ensure config dir exists with restrictive perms (best-effort on non-unix). */
export function ensureConfigDir(dir = defaultConfigDir()) {
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true, mode: 0o700 });
    try {
      chmodSync(dir, 0o700);
    } catch {
      /* windows */
    }
  }
  return dir;
}

/**
 * Load or generate SWITCHYARD_LOCAL_TOKEN for loopback abuse guard.
 * Preference: process.env.SWITCHYARD_LOCAL_TOKEN > file ~/.switchyard-offline/token
 */
export function loadOrCreateLocalToken(opts = {}) {
  if (process.env.SWITCHYARD_LOCAL_TOKEN) {
    return String(process.env.SWITCHYARD_LOCAL_TOKEN);
  }
  if (opts.token) return String(opts.token);

  const dir = ensureConfigDir(opts.configDir || defaultConfigDir(opts.home));
  const tokenPath = join(dir, 'token');
  if (existsSync(tokenPath)) {
    return readFileSync(tokenPath, 'utf8').trim();
  }
  const token = randomBytes(24).toString('base64url');
  writeFileSync(tokenPath, token, { mode: 0o600 });
  try {
    chmodSync(tokenPath, 0o600);
  } catch {
    /* windows */
  }
  return token;
}

/**
 * Resolve provider API key: env first, then keys.json.
 * keys.json shape: { "openai": "...", "anthropic": "...", "nvidia": "..." }
 */
export function getProviderKey(providerId, opts = {}) {
  const envName = PROVIDER_ENV[providerId];
  if (envName && process.env[envName]) {
    return String(process.env[envName]);
  }

  const dir = opts.configDir || defaultConfigDir(opts.home);
  const keysPath = join(dir, 'keys.json');
  if (!existsSync(keysPath)) return null;
  try {
    const raw = JSON.parse(readFileSync(keysPath, 'utf8'));
    const v = raw[providerId] || raw[providerId.toUpperCase()];
    return v ? String(v) : null;
  } catch {
    return null;
  }
}

export function makeGetToken(opts = {}) {
  return async (providerId) => getProviderKey(providerId, opts);
}
