#!/usr/bin/env node
// Map provider keys onto the env vars the pin's TOML names via api_key_env.
// Prints `export NAME=...` lines for the entrypoint to eval. Never prints a
// value to stderr, and never logs one.
//
// THE VAULT IS THE STORE. This read the `keys` block of /state/sources.json,
// and that had become the wrong half of a half-finished move: server.mjs
// already REFUSES key material on POST /api/sources with
//
//     key_moved_to_vault: provider keys live in vault now
//
// so nothing could write that block any more, while this still read it. A
// deployment whose keys were in the vault -- where the API tells you to put
// them -- got a pin with no providers and every completion routed to the
// discard port. A deployment whose keys were still in the file worked, and
// looked like proof the file was the store.
//
// So: the vault first, and when the vault is configured it is AUTHORITATIVE.
// If it holds no key for a vendor, that vendor has no key. Falling back to the
// file there would silently prefer a stale credential over the store of
// record, which is the same failure one layer down -- and vault.mjs already
// states the rule for the other path: "Absent, unconfigured, or refused all
// read the same: no usable key. There is no fallback credential."
//
// THE FILE STILL WORKS WHEN THERE IS NO VAULT, because a substrate that
// bricked every un-migrated pod to make a point would be a worse substrate.
// That path announces itself on stderr, by name, without values.
//
// READ AT BOOT, NOT PER REQUEST. The pin gets a generated TOML at start-up, so
// a key placed afterwards takes effect on the next restart of this container.
// That is inherent to Shape D rather than a choice made here; vault.mjs reads
// per request because the leftover's own remote path can.
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

// The leftover's own vault client, reused rather than reimplemented: one
// slot-naming rule (switchyard.<vendor>), one refusal shape, one place to fix.
import { vaultKey } from '/switch/vault.mjs';

const STATE_DIR = process.env.SWITCH_STATE_DIR || '/state';
const STATE_FILE = join(STATE_DIR, 'sources.json');

const VENDOR_ENV = Object.freeze({
  openai: 'OPENAI_API_KEY',
  anthropic: 'ANTHROPIC_API_KEY',
  nvidia: 'NVIDIA_API_KEY',
  fireworks: 'FIREWORKS_API_KEY',
  openrouter: 'OPENROUTER_API_KEY',
});

const vaultConfigured = Boolean(process.env.VAULT_URL && process.env.SWITCH_VAULT_TOKEN);

function loadFileKeys() {
  try {
    if (!existsSync(STATE_FILE)) return {};
    const state = JSON.parse(readFileSync(STATE_FILE, 'utf8'));
    return (state && state.keys) || {};
  } catch {
    return {};
  }
}

const fileKeys = vaultConfigured ? {} : loadFileKeys();

if (!vaultConfigured) {
  process.stderr.write(
    '[inject_env] VAULT_URL/SWITCH_VAULT_TOKEN unset: falling back to the ' +
    'sources.json keys block, which server.mjs no longer lets anything write. ' +
    'Set both and place keys with vault.secret.put.\n',
  );
}

const placed = [];
const missing = [];

for (const [vendor, envName] of Object.entries(VENDOR_ENV)) {
  // An explicit env var still wins. It is how an operator overrides one vendor
  // without touching a store, and how a test runs with no vault at all.
  if (process.env[envName]) { placed.push(`${vendor}:env`); continue; }

  let value = null;
  let source = null;

  if (vaultConfigured) {
    // Null covers absent, unreachable and refused alike -- vault.mjs collapses
    // them deliberately, because to a caller they are the same condition.
    value = await vaultKey(vendor);
    source = 'vault';
  } else {
    const fromFile = fileKeys[vendor];
    if (typeof fromFile === 'string' && fromFile.trim()) { value = fromFile; source = 'file'; }
  }

  if (typeof value === 'string' && value.trim()) {
    process.stdout.write(`export ${envName}=${JSON.stringify(value)}\n`);
    placed.push(`${vendor}:${source}`);
  } else {
    missing.push(vendor);
  }
}

// Names and sources only. Which vendors are configured is operational fact a
// reader needs at boot; the values are not, and never appear here.
process.stderr.write(
  `[inject_env] keys placed: ${placed.length ? placed.join(', ') : '(none)'}` +
  `${missing.length ? ` | no key for: ${missing.join(', ')}` : ''}\n`,
);
