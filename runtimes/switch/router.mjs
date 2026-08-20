// runtimes/switch/router.mjs -- query -> model mapping, decided by the LOCAL model.
//
// WHY THE LOCAL MODEL DOES THIS: choosing a destination well needs to look at the
// query, and looking at the query is exactly what SwitchYard.offline refuses to do
// remotely. Running the classifier on the on-device model keeps content-aware
// routing without the content leaving the device -- so ollama is REQUIRED even
// when a remote provider serves the answer. The prompt reaches a remote provider
// only after this local decision selects it.
//
// The classifier is a one-word label pick, which small local models do reliably --
// unlike the structured-output generation MIND itself needs.
import { LOCAL_ID, OLLAMA_URL } from './sources.mjs';

const CLASSIFY_TIMEOUT_MS = Number(process.env.SWITCH_ROUTE_TIMEOUT_MS || 20000);

/** First user-authored text in an OpenAI-shaped body, bounded. */
export function queryText(body = {}) {
  const msgs = Array.isArray(body.messages) ? body.messages : [];
  const user = msgs.filter((m) => m.role === 'user').pop() || msgs[msgs.length - 1];
  const c = user && user.content;
  const text = typeof c === 'string'
    ? c
    : Array.isArray(c) ? c.map((b) => (b && b.text) || '').join(' ') : '';
  return text.slice(0, 800);
}

/** Heuristic used when the classifier is unavailable or answers off-menu. */
export function heuristic(body, candidates) {
  const wantsTools = Array.isArray(body && body.tools) && body.tools.length > 0;
  const remote = candidates.find((c) => c !== LOCAL_ID);
  // Structured output / tool calling is where small local models fail, so send it
  // to a remote provider when one is configured.
  if (wantsTools && remote) return remote;
  return candidates.includes(LOCAL_ID) ? LOCAL_ID : candidates[0];
}

export function buildPrompt(body, candidates, localModel) {
  return [
    'You are a routing classifier. Choose which model should answer the request.',
    `Options: ${candidates.join(', ')}`,
    `- ${LOCAL_ID}: a small local model. Good for short, simple, plain-text answers.`,
    '- any other option: a large remote model. Use it for long, complex, or',
    '  tool-calling / structured-output requests.',
    body && Array.isArray(body.tools) && body.tools.length
      ? 'This request uses tool calling.'
      : 'This request does not use tool calling.',
    '',
    `Request: ${queryText(body)}`,
    '',
    `Answer with exactly one of: ${candidates.join(', ')}. No other words.`,
  ].join('\n');
}

/**
 * Map a query to a source id. Never throws: any failure falls back to the
 * heuristic, so a sick classifier degrades routing rather than breaking it.
 */
export async function route(body, candidates, opts = {}) {
  const ids = candidates.filter(Boolean);
  if (ids.length <= 1) return { id: ids[0] || LOCAL_ID, by: 'only-candidate' };

  const localModel = opts.localModel;
  const fetchImpl = opts.fetchImpl || globalThis.fetch;
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), CLASSIFY_TIMEOUT_MS);
  try {
    const r = await fetchImpl(`${opts.ollamaUrl || OLLAMA_URL}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      signal: ctl.signal,
      body: JSON.stringify({
        model: localModel,
        messages: [{ role: 'user', content: buildPrompt(body, ids, localModel) }],
        max_tokens: 8,
        temperature: 0,
      }),
    });
    if (!r.ok) return { id: heuristic(body, ids), by: 'heuristic', because: `classifier http ${r.status}` };
    const j = await r.json();
    const said = String(((j.choices || [])[0]?.message?.content) || '').toLowerCase();
    const hit = ids.find((id) => said.includes(id.toLowerCase()));
    if (hit) return { id: hit, by: 'local-classifier' };
    return { id: heuristic(body, ids), by: 'heuristic', because: 'classifier answered off-menu' };
  } catch (e) {
    return { id: heuristic(body, ids), by: 'heuristic', because: e.name === 'AbortError' ? 'classifier timeout' : String(e.message || e) };
  } finally {
    clearTimeout(timer);
  }
}
