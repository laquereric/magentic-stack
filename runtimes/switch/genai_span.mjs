// runtimes/switch/genai_span.mjs -- GenAI semantic-convention spans, no SDK.
//
// ADR 0058 / GAP 74: OTEL is the vocabulary, not the floor, and not a
// dependency. This file emits gen_ai.* attributes as JSON. Local append
// happens first. OTLP is optional (OTEL_EXPORTER_OTLP_TRACES_ENDPOINT)
// and must not fail the request. Logfire is not imported. Prompts,
// messages, and credentials never become attributes.

import { appendFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

export const SCOPE_NAME = 'switch/genai';
export const SCOPE_VERSION = '1';

const FORBIDDEN = [
  'authorization', 'cookie', 'set-cookie', 'session_token', 'api_key',
  'password', 'email', 'token', 'prompt', 'messages', 'content',
  'completion', 'gen_ai.input.messages', 'gen_ai.output.messages',
  'gen_ai.prompt', 'gen_ai.completion',
];

export function hexId(bytes) {
  return randomBytes(bytes).toString('hex');
}

export function parseTraceparent(header) {
  const s = String(header || '').trim();
  const parts = s.split('-');
  if (parts.length >= 4 && /^[0-9a-f]{32}$/i.test(parts[1]) && /^[0-9a-f]{16}$/i.test(parts[2])) {
    return { traceId: parts[1].toLowerCase(), parentSpanId: parts[2].toLowerCase() };
  }
  return { traceId: hexId(16), parentSpanId: '' };
}

function dropForbidden(attrs) {
  const out = {};
  for (const [k, v] of Object.entries(attrs || {})) {
    const key = String(k);
    if (FORBIDDEN.includes(key.toLowerCase()) || FORBIDDEN.includes(key)) continue;
    if (v == null || v === '') continue;
    out[key] = v;
  }
  return out;
}

export function chatSpan({ provider, model, traceparent, status, reason, usage, durationMs }) {
  const ids = parseTraceparent(traceparent);
  const name = `chat ${model || provider || 'unknown'}`;
  const attributes = dropForbidden({
    'gen_ai.operation.name': 'chat',
    'gen_ai.provider.name': provider || undefined,
    'gen_ai.request.model': model || undefined,
    'gen_ai.usage.input_tokens': usage && usage.input,
    'gen_ai.usage.output_tokens': usage && usage.output,
    'error.type': status === 'ERROR' ? (reason || 'error') : undefined,
  });
  return {
    name,
    kind: 'CLIENT',
    traceId: ids.traceId,
    spanId: hexId(8),
    parentSpanId: ids.parentSpanId || undefined,
    status: { code: status === 'ERROR' ? 'ERROR' : 'UNSET' },
    durationMs: Number(durationMs) || 0,
    attributes,
    'otel.scope.name': SCOPE_NAME,
    'otel.scope.version': SCOPE_VERSION,
  };
}

export function usageFromBody(text) {
  if (!text || typeof text !== 'string') return null;
  try {
    const j = JSON.parse(text);
    const u = j && j.usage;
    if (!u || typeof u !== 'object') return null;
    const input = u.input_tokens ?? u.prompt_tokens;
    const output = u.output_tokens ?? u.completion_tokens;
    if (input == null && output == null) return null;
    return { input, output };
  } catch {
    return null;
  }
}

function writeLocal(span) {
  const line = JSON.stringify({ gen_ai_span: span });
  const path = String(process.env.GENAI_SPAN_LOG || '').trim();
  if (path) {
    appendFileSync(path, line + '\n');
    return;
  }
  console.log(line);
}

async function exportOtlp(span) {
  const url = String(process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT || '').trim();
  if (!url) return;
  const attrs = Object.entries(span.attributes || {}).map(([key, value]) => {
    if (typeof value === 'number') return { key, value: { intValue: String(Math.trunc(value)) } };
    return { key, value: { stringValue: String(value) } };
  });
  const body = {
    resourceSpans: [{
      resource: { attributes: [{ key: 'service.name', value: { stringValue: 'switch' } }] },
      scopeSpans: [{
        scope: { name: SCOPE_NAME, version: SCOPE_VERSION },
        spans: [{
          traceId: span.traceId,
          spanId: span.spanId,
          parentSpanId: span.parentSpanId || '',
          name: span.name,
          kind: 3,
          startTimeUnixNano: '0',
          endTimeUnixNano: String(Math.max(0, Math.trunc((span.durationMs || 0) * 1e6))),
          status: { code: span.status && span.status.code === 'ERROR' ? 2 : 0 },
          attributes: attrs,
        }],
      }],
    }],
  };
  await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}

export function emitChat(args) {
  try {
    const span = chatSpan(args);
    writeLocal(span);
    exportOtlp(span).catch(() => {});
    return span;
  } catch {
    return null;
  }
}
