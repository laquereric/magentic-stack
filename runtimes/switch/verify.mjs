// runtimes/switch/verify.mjs -- prove tool support instead of assuming it.
//
// Discovery tells us a model EXISTS; no vendor API tells us whether it can
// actually drive a tool call. We assumed true, which is the same class of
// mistake as the hardcoded catalog: an assumption that reads as a fact. The only
// honest answer is to ask the model to make one tool call and see what happens.
//
// This costs one tiny billed request per model, so it is on demand, never
// automatic on discovery.

const PROBE_TOOL = Object.freeze({
  type: 'function',
  function: {
    name: 'ping',
    description: 'Return the number you were given.',
    parameters: {
      type: 'object',
      properties: { value: { type: 'integer' } },
      required: ['value'],
    },
  },
});

export function probeRequest(model) {
  return {
    model,
    max_tokens: 64,
    temperature: 0,
    messages: [{ role: 'user', content: 'Call the ping tool with value 1.' }],
    tools: [PROBE_TOOL],
    tool_choice: 'required',
  };
}

/** Did the model actually emit a tool call? */
export function sawToolCall(payload) {
  const choice = ((payload && payload.choices) || [])[0] || {};
  const calls = (choice.message && choice.message.tool_calls) || [];
  return Array.isArray(calls) && calls.length > 0;
}

// A provider that rejects the request BECAUSE of tools is a definitive no; any
// other failure (auth, rate limit, network) says nothing about tool support and
// must not be recorded as evidence.
const TOOLS_REJECTED = /tool|function[_ ]call|not supported|unsupported/i;

export function classify(out) {
  if (out && out.json) {
    const because = String((out.json.because || '') + ' ' + (out.json.reason || ''));
    if (TOOLS_REJECTED.test(because)) {
      return { tools: false, verified: true, because: because.trim() };
    }
    return { verified: false, because: because.trim() || 'call failed' };
  }
  let payload;
  try { payload = JSON.parse((out && out.text) || '{}'); } catch { payload = {}; }
  if (payload && payload.error) {
    const msg = String(payload.error.message || payload.error);
    if (TOOLS_REJECTED.test(msg)) return { tools: false, verified: true, because: msg };
    return { verified: false, because: msg };
  }
  if (sawToolCall(payload)) return { tools: true, verified: true, because: 'returned a tool call' };
  return { tools: false, verified: true, because: 'answered without calling the tool' };
}

/**
 * Verify one model. `complete` is the pod's dispatcher, so this exercises the
 * real path a routed request would take, translation included.
 */
export async function verifyModel(vendor, model, complete) {
  try {
    const out = await complete(vendor, model, probeRequest(model));
    return { vendor, model, ...classify(out) };
  } catch (e) {
    return { vendor, model, verified: false, because: String((e && e.message) || e) };
  }
}
