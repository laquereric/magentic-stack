// runtimes/switch/translate.mjs -- OpenAI Chat <-> Anthropic Messages.
//
// MIND speaks OpenAI (litellm/NOOA). Anthropic does not accept that shape, so a
// request routed to Anthropic is translated here and its reply translated back.
// Tool calling MUST survive the round trip: NOOA's whole contract is a tool call
// (return_result -> NoteInsight), so dropping tools would silently break it.

/** OpenAI request -> Anthropic Messages request. */
export function toAnthropicRequest(body = {}, model) {
  const messages = Array.isArray(body.messages) ? body.messages : [];
  const system = messages.filter((m) => m.role === 'system').map((m) => m.content).join('\n\n');

  const out = {
    model,
    // Anthropic requires max_tokens; OpenAI treats it as optional.
    max_tokens: body.max_tokens || body.max_completion_tokens || 1024,
    messages: messages.filter((m) => m.role !== 'system').map(toAnthropicMessage),
  };
  if (system) out.system = system;
  if (typeof body.temperature === 'number') out.temperature = body.temperature;

  if (Array.isArray(body.tools) && body.tools.length) {
    out.tools = body.tools
      .filter((t) => t && t.function)
      .map((t) => ({
        name: t.function.name,
        description: t.function.description || '',
        input_schema: t.function.parameters || { type: 'object', properties: {} },
      }));
  }
  if (body.tool_choice === 'required') out.tool_choice = { type: 'any' };
  else if (body.tool_choice && body.tool_choice.function) {
    out.tool_choice = { type: 'tool', name: body.tool_choice.function.name };
  }
  return out;
}

function toAnthropicMessage(m) {
  // An assistant turn carrying tool calls becomes tool_use content blocks.
  if (m.role === 'assistant' && Array.isArray(m.tool_calls) && m.tool_calls.length) {
    const blocks = [];
    if (m.content) blocks.push({ type: 'text', text: String(m.content) });
    for (const c of m.tool_calls) {
      blocks.push({
        type: 'tool_use',
        id: c.id,
        name: c.function && c.function.name,
        input: safeParse(c.function && c.function.arguments),
      });
    }
    return { role: 'assistant', content: blocks };
  }
  // A tool result turn becomes a user tool_result block.
  if (m.role === 'tool') {
    return {
      role: 'user',
      content: [{ type: 'tool_result', tool_use_id: m.tool_call_id, content: String(m.content ?? '') }],
    };
  }
  return { role: m.role === 'assistant' ? 'assistant' : 'user', content: String(m.content ?? '') };
}

/** Anthropic Messages response -> OpenAI Chat response. */
export function toOpenAiResponse(a = {}, model) {
  const blocks = Array.isArray(a.content) ? a.content : [];
  const text = blocks.filter((b) => b.type === 'text').map((b) => b.text).join('');
  const toolCalls = blocks
    .filter((b) => b.type === 'tool_use')
    .map((b, i) => ({
      id: b.id || `call_${i}`,
      type: 'function',
      function: { name: b.name, arguments: JSON.stringify(b.input ?? {}) },
    }));

  const message = { role: 'assistant', content: text || null };
  if (toolCalls.length) message.tool_calls = toolCalls;

  return {
    id: a.id || 'chatcmpl-switchyard',
    object: 'chat.completion',
    created: 0,
    model: a.model || model,
    choices: [{
      index: 0,
      message,
      finish_reason: toolCalls.length ? 'tool_calls' : finish(a.stop_reason),
    }],
    usage: {
      prompt_tokens: (a.usage && a.usage.input_tokens) || 0,
      completion_tokens: (a.usage && a.usage.output_tokens) || 0,
      total_tokens: ((a.usage && a.usage.input_tokens) || 0) + ((a.usage && a.usage.output_tokens) || 0),
    },
  };
}

function finish(stop) {
  if (stop === 'max_tokens') return 'length';
  if (stop === 'tool_use') return 'tool_calls';
  return 'stop';
}

function safeParse(s) {
  if (!s) return {};
  try { return typeof s === 'string' ? JSON.parse(s) : s; } catch { return {}; }
}

// Fields an OpenAI-compatible chat message may carry. Anything else is a vendor
// extension: litellm attaches Anthropic's `cache_control` for prompt caching, and
// a strict validator rejects the WHOLE request over it -- Fireworks answers
// "Extra inputs are not permitted, field: 'messages[0].cache_control'" with a 400.
// Switch is the translation layer, so it sanitizes toward the target rather than
// asking every caller to know which vendor its prompt will land on. Anthropic
// keeps its own extensions: that path goes through toAnthropicRequest instead.
const OPENAI_MESSAGE_FIELDS = new Set([
  'role', 'content', 'name', 'tool_calls', 'tool_call_id', 'refusal',
]);

/** Strip vendor extensions from messages; report what went, so it is not silent. */
export function sanitizeMessages(messages) {
  if (!Array.isArray(messages)) return { messages, dropped: [] };
  const dropped = new Set();
  const clean = messages.map((m) => {
    if (!m || typeof m !== 'object' || Array.isArray(m)) return m;
    const keep = {};
    for (const k of Object.keys(m)) {
      if (OPENAI_MESSAGE_FIELDS.has(k)) keep[k] = m[k];
      else dropped.add(k);
    }
    return keep;
  });
  return { messages: clean, dropped: [...dropped].sort() };
}
