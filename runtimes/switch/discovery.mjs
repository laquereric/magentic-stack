// runtimes/switch/discovery.mjs -- ask each vendor which models the key opens.
//
// WHY THIS EXISTS: a hardcoded model list is wrong the day a vendor ships. Ours
// shipped claude-3-5-haiku-20241022, which 404'd because the account offers
// claude-haiku-4-5 instead. Existence is the VENDOR's fact, so we ask; the
// catalog is only an overlay for the things an API does not report (price,
// tool support), and anything it does not know stays explicitly unknown.
import { egressAny as egress, basePath } from './providers.mjs';
import { OLLAMA_URL } from './sources.mjs';

// Vendors return everything they host, including embeddings and audio. Routing
// wants chat models, so keep the filter per vendor rather than guessing globally.
const NOT_CHAT = /(embed|embedding|rerank|reranker|tts|whisper|audio|image|vision-encoder|moderation|guard|transcribe|speech)/i;

const CHATTY = {
  openai: (id) => /^(gpt-|o[1-9])/.test(id) && !NOT_CHAT.test(id),
  // Fireworks serves embeddings and rerankers from the same catalog as chat.
  fireworks: (id) => !NOT_CHAT.test(id),
  anthropic: (id) => !NOT_CHAT.test(id),
  nvidia: (id) => !NOT_CHAT.test(id),
  ollama: (id) => !NOT_CHAT.test(id),
  // OpenRouter lists every model it brokers, including embeddings and
  // media, and marks free tiers with a `:free` suffix that is still a chat
  // model. Filter on what it is, not on how it is priced.
  openrouter: (id) => !NOT_CHAT.test(id),
};

function parseIds(vendorId, payload) {
  const rows = Array.isArray(payload && payload.data) ? payload.data
    : Array.isArray(payload && payload.models) ? payload.models
    : [];
  const keep = CHATTY[vendorId] || (() => true);
  return rows
    .map((r) => String(r.id || r.name || ''))
    .filter(Boolean)
    .filter(keep)
    .sort();
}

// An EMPTY result is a failure, not a truth. Overwriting a known model list with
// [] would leave the vendor showing nothing at all, which is strictly worse than
// showing catalog defaults -- so refuse it and let the caller keep what it had.
function accept(vendorId, models) {
  if (!models.length) {
    return { ok: false, reason: 'discover_empty', because: `${vendorId} returned no usable chat models` };
  }
  return { ok: true, models };
}

/**
 * Discover models for one vendor. Never throws: a vendor that cannot be reached
 * returns an explanation, and the caller keeps whatever it already had.
 */
export async function discover(vendorId, state, opts = {}) {
  // state is kept for signature stability; the credential comes from
  // opts.token (vault, row 11 slice A), never the state file.
  const fetchImpl = opts.fetchImpl || globalThis.fetch;

  if (vendorId === 'ollama') {
    try {
      const r = await fetchImpl(`${opts.ollamaUrl || OLLAMA_URL}/v1/models`);
      if (!r.ok) return { ok: false, reason: 'discover_failed', because: `ollama http ${r.status}` };
      return accept('ollama', parseIds('ollama', await r.json()));
    } catch (e) {
      return { ok: false, reason: 'discover_failed', because: `ollama unreachable: ${e.message || e}` };
    }
  }

  const token = opts.token !== undefined ? opts.token : null;
  if (!token) return { ok: false, reason: 'missing_credential', because: `no key for ${vendorId}` };

  // Through the same gate as everything else: allowlist, TLS and path all apply.
  // Not every vendor serves under /v1 -- Fireworks uses /inference/v1.
  const eg = await egress({ providerId: vendorId, path: `${basePath(vendorId)}/models`, method: 'GET', token, fetchImpl: opts.fetchImpl });
  if (!eg.ok) {
    const e = eg.error || eg;
    return { ok: false, reason: e.reason, because: e.because };
  }
  return accept(vendorId, parseIds(vendorId, (eg.result && eg.result.body) || {}));
}
