// The vendor table: built-ins, plus whatever /state declares.
//
// ONE LIST, NOT TWO. generate_config.mjs and inject_env.mjs each carried their
// own frozen copy of the same five vendors -- one mapping id to base_url, the
// other mapping id to env var. Adding a provider meant editing both, and
// forgetting one produced a client with no key or a key with no client, neither
// of which says what is wrong. They both read this now.
//
// AND IT IS NO LONGER CLOSED. A provider was an image rebuild: two frozen maps,
// a Rust-stage build, a publish, and a repin of every consumer -- for a base URL
// and an env var name. sources.json already carries per-vendor state, so a
// vendor can be declared there:
//
//   "vendors": {
//     "zen": { "format": "openai_chat",
//              "base_url": "https://example.invalid/v1",
//              "env": "ZEN_API_KEY" }
//   }
//
// and the key goes in the vault at switchyard.zen like any other.
//
// STATE MAY ADD, NEVER REDEFINE. A built-in cannot be overridden from
// sources.json, and that is deliberate: `base_url` is where a credential is
// sent, so a state file that could repoint `openai` would be a state file that
// could exfiltrate the OpenAI key to anywhere. Declaring a new id is additive
// and carries no such power; redefining an existing one is refused by name.
//
// REFUSED LOUDLY, NEVER DROPPED. A malformed entry is announced on stderr and
// skipped. Silently ignoring it would leave an operator looking at a vendor
// they configured, a pin that has never heard of it, and nothing to read.
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

// Formats the pin actually implements. A vendor may not invent one.
const FORMATS = Object.freeze(['openai_chat', 'anthropic_messages']);

// Ids that would collide with the pin's own reserved clients.
const RESERVED = Object.freeze(['dummy', 'ollama']);

export const BUILT_IN = Object.freeze({
  openai: { format: 'openai_chat', base_url: 'https://api.openai.com/v1', env: 'OPENAI_API_KEY' },
  anthropic: { format: 'anthropic_messages', base_url: 'https://api.anthropic.com', env: 'ANTHROPIC_API_KEY' },
  nvidia: { format: 'openai_chat', base_url: 'https://integrate.api.nvidia.com/v1', env: 'NVIDIA_API_KEY' },
  fireworks: { format: 'openai_chat', base_url: 'https://api.fireworks.ai/inference/v1', env: 'FIREWORKS_API_KEY' },
  openrouter: { format: 'openai_chat', base_url: 'https://openrouter.ai/api/v1', env: 'OPENROUTER_API_KEY' },
  // OpenCode Zen. Kept built-in rather than left to state because it is the
  // route measured to emit a tool call on a free tier, which is what NOOA
  // needs -- verified with tool_choice="required", since a route can accept the
  // tools parameter and never call one.
  opencode: { format: 'openai_chat', base_url: 'https://opencode.ai/zen/v1', env: 'OPENCODE_API_KEY' },
});

const ID_RE = /^[a-z][a-z0-9_-]*$/;
const ENV_RE = /^[A-Z][A-Z0-9_]*$/;

function warn(message) {
  process.stderr.write(`[vendors] ${message}\n`);
}

/** The declared vendors in a state object, validated. Never throws. */
export function fromState(state) {
  const declared = state && state.vendors;
  if (!declared || typeof declared !== 'object') return {};

  const out = {};
  for (const [id, spec] of Object.entries(declared)) {
    if (!ID_RE.test(id)) {
      warn(`refusing vendor ${JSON.stringify(id)}: id must match ${ID_RE}`); continue;
    }
    if (RESERVED.includes(id)) {
      warn(`refusing vendor ${id}: reserved by the pin`); continue;
    }
    if (Object.prototype.hasOwnProperty.call(BUILT_IN, id)) {
      // See the header: base_url is where a credential is sent.
      warn(`refusing vendor ${id}: built in, and state may add but not redefine`); continue;
    }
    if (!spec || typeof spec !== 'object') {
      warn(`refusing vendor ${id}: spec must be an object`); continue;
    }

    const format = String(spec.format || 'openai_chat');
    if (!FORMATS.includes(format)) {
      warn(`refusing vendor ${id}: format ${format} is not one of ${FORMATS.join(', ')}`); continue;
    }

    const base = String(spec.base_url || '');
    if (!base.startsWith('https://')) {
      // A credential goes to this host on every request.
      warn(`refusing vendor ${id}: base_url must be https`); continue;
    }

    const env = String(spec.env || `${id.toUpperCase().replace(/-/g, '_')}_API_KEY`);
    if (!ENV_RE.test(env)) {
      warn(`refusing vendor ${id}: env ${env} is not a usable variable name`); continue;
    }

    out[id] = { format, base_url: base, env };
  }
  return out;
}

/** Read sources.json without caring whether it is there. */
export function readState(stateDir) {
  const dir = stateDir || process.env.SWITCH_STATE_DIR || '/state';
  try {
    const file = join(dir, 'sources.json');
    if (!existsSync(file)) return {};
    return JSON.parse(readFileSync(file, 'utf8')) || {};
  } catch {
    return {};
  }
}

/** Built-ins plus whatever state legitimately adds. */
export function vendors(state) {
  return Object.freeze({ ...BUILT_IN, ...fromState(state || readState()) });
}

/** id -> env var name, for every vendor this pod knows. */
export function vendorEnv(state) {
  const out = {};
  for (const [id, spec] of Object.entries(vendors(state))) out[id] = spec.env;
  return out;
}
