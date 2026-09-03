#!/usr/bin/env node
// Emit a content-blind switchyard-server TOML.
// Allowed algorithms: noop, passthrough, random.
// Never emits llm_classifier or stage_router.
import { writeFileSync, mkdirSync, readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ALLOWED = Object.freeze(['noop', 'passthrough', 'random']);
const HERE = dirname(fileURLToPath(import.meta.url));

const VENDORS = Object.freeze({
  openai: { format: 'openai_chat', base_url: 'https://api.openai.com/v1', env: 'OPENAI_API_KEY' },
  anthropic: { format: 'anthropic_messages', base_url: 'https://api.anthropic.com', env: 'ANTHROPIC_API_KEY' },
  nvidia: { format: 'openai_chat', base_url: 'https://integrate.api.nvidia.com/v1', env: 'NVIDIA_API_KEY' },
  fireworks: { format: 'openai_chat', base_url: 'https://api.fireworks.ai/inference/v1', env: 'FIREWORKS_API_KEY' },
  openrouter: { format: 'openai_chat', base_url: 'https://openrouter.ai/api/v1', env: 'OPENROUTER_API_KEY' },
});

function assertAllowed(type) {
  if (!ALLOWED.includes(type)) {
    throw new Error(`refusing algorithm type ${type}; content-blind allows ${ALLOWED.join(', ')}`);
  }
}

function tomlString(value) {
  return JSON.stringify(String(value));
}

function tomlKey(value) {
  return String(value).replace(/[^A-Za-z0-9]+/g, '_').replace(/^_|_$/g, '') || 'x';
}

function catalogVendors() {
  const candidates = [
    '/switch/llm_catalog.json',
    join(HERE, '../../../runtimes/mind-pod/app/config/llm_catalog.json'),
    join(HERE, '../../runtimes/mind-pod/app/config/llm_catalog.json'),
  ];
  for (const p of candidates) {
    if (existsSync(p)) {
      try {
        const data = JSON.parse(readFileSync(p, 'utf8'));
        return (data && data.vendors) || {};
      } catch {
        return {};
      }
    }
  }
  return {};
}

function loadState() {
  const dir = process.env.SWITCH_STATE_DIR || '/state';
  const file = join(dir, 'sources.json');
  try {
    if (!existsSync(file)) return {};
    return JSON.parse(readFileSync(file, 'utf8')) || {};
  } catch {
    return {};
  }
}

function modelsFor(vendor, catalog, state) {
  const discovered = state.discovered && state.discovered[vendor];
  if (Array.isArray(discovered) && discovered.length) {
    return discovered.map((m) => (typeof m === 'string' ? m : m && m.id)).filter(Boolean);
  }
  const seeded = catalog[vendor] && catalog[vendor].models;
  if (Array.isArray(seeded)) return seeded.map((m) => m && m.id).filter(Boolean);
  return [];
}

function emit() {
  const catalog = catalogVendors();
  const state = loadState();
  const lines = [];
  lines.push('schema_version = 1');
  lines.push('');
  lines.push('# generated; algorithms: noop, passthrough, random only');
  lines.push('');
  lines.push('[llm_clients.dummy]');
  lines.push('format = "openai_chat"');
  lines.push('base_url = "http://127.0.0.1:9/v1"');
  lines.push('');
  lines.push('[targets.dummy]');
  lines.push('id = "dummy/model"');
  lines.push('llm_client = "dummy"');

  const randomTargets = [];

  for (const [vendor, spec] of Object.entries(VENDORS)) {
    const key = process.env[spec.env];
    if (!key || !String(key).trim()) continue;
    const client = vendor;
    lines.push('');
    lines.push(`[llm_clients.${client}]`);
    lines.push(`format = ${tomlString(spec.format)}`);
    lines.push(`base_url = ${tomlString(spec.base_url)}`);
    lines.push(`api_key_env = ${tomlString(spec.env)}`);
    const models = modelsFor(vendor, catalog, state);
    const ids = models.length ? models : [`${vendor}/default`];
    for (const modelId of ids) {
      assertAllowed('passthrough');
      const keyName = tomlKey(`${vendor}_${modelId}`);
      lines.push('');
      lines.push(`[targets.${keyName}]`);
      lines.push(`id = ${tomlString(modelId)}`);
      lines.push(`llm_client = ${tomlString(client)}`);
      lines.push('');
      lines.push(`[routes.${keyName}]`);
      lines.push(`id = ${tomlString(`${vendor}:${modelId}`)}`);
      lines.push('type = "passthrough"');
      lines.push(`target = ${tomlString(keyName)}`);
      randomTargets.push(keyName);
    }
  }

  const ollama = process.env.OLLAMA_URL;
  if (ollama && String(ollama).trim()) {
    const base = String(ollama).replace(/\/$/, '') + '/v1';
    lines.push('');
    lines.push('[llm_clients.ollama]');
    lines.push('format = "openai_chat"');
    lines.push(`base_url = ${tomlString(base)}`);
    const models = modelsFor('ollama', catalog, state);
    const ids = models.length ? models : ['llama3.2:1b'];
    for (const modelId of ids) {
      assertAllowed('passthrough');
      const keyName = tomlKey(`ollama_${modelId}`);
      lines.push('');
      lines.push(`[targets.${keyName}]`);
      lines.push(`id = ${tomlString(modelId)}`);
      lines.push('llm_client = "ollama"');
      lines.push('');
      lines.push(`[routes.${keyName}]`);
      lines.push(`id = ${tomlString(`ollama:${modelId}`)}`);
      lines.push('type = "passthrough"');
      lines.push(`target = ${tomlString(keyName)}`);
      randomTargets.push(keyName);
    }
  }

  if (!randomTargets.length) randomTargets.push('dummy');

  assertAllowed('noop');
  lines.push('');
  lines.push('[routes.noop]');
  lines.push('id = "switchyard/noop"');
  lines.push('type = "noop"');

  assertAllowed('passthrough');
  lines.push('');
  lines.push('[routes.passthrough]');
  lines.push('id = "switchyard/passthrough"');
  lines.push('type = "passthrough"');
  lines.push('target = "dummy"');

  assertAllowed('random');
  lines.push('');
  lines.push('[routes.random]');
  lines.push('id = "switchyard/random"');
  lines.push('type = "random"');
  lines.push(`targets = [${randomTargets.map(tomlString).join(', ')}]`);
  lines.push('');
  return lines.join('\n');
}

const outIdx = process.argv.indexOf('--out');
const out = outIdx >= 0 ? process.argv[outIdx + 1] : '';
const body = emit();
if (!out) {
  process.stdout.write(body);
} else {
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, body, { encoding: 'utf8' });
}
