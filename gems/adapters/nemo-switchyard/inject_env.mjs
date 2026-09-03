#!/usr/bin/env node
// Map leftover Node /state keys onto env vars the pin's TOML names via
// api_key_env. Prints `export NAME=...` lines for the entrypoint to eval.
// Does not print values to stderr. Does not read .agent/secrets itself --
// compose already bind-mounts that directory at /state (row 46).
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const STATE_DIR = process.env.SWITCH_STATE_DIR || '/state';
const STATE_FILE = join(STATE_DIR, 'sources.json');

const VENDOR_ENV = Object.freeze({
  openai: 'OPENAI_API_KEY',
  anthropic: 'ANTHROPIC_API_KEY',
  nvidia: 'NVIDIA_API_KEY',
  fireworks: 'FIREWORKS_API_KEY',
  openrouter: 'OPENROUTER_API_KEY',
});

function loadKeys() {
  try {
    if (!existsSync(STATE_FILE)) return {};
    const state = JSON.parse(readFileSync(STATE_FILE, 'utf8'));
    return (state && state.keys) || {};
  } catch {
    return {};
  }
}

const keys = loadKeys();
for (const [vendor, envName] of Object.entries(VENDOR_ENV)) {
  if (process.env[envName]) continue;
  const value = keys[vendor];
  if (typeof value === 'string' && value.trim()) {
    process.stdout.write(`export ${envName}=${JSON.stringify(value)}\n`);
  }
}
