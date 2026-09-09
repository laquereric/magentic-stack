import net from 'node:net';
import { URL } from 'node:url';
import crypto from 'node:crypto';

// runtimes/switch/vault.mjs -- provider keys from VAULT, never the file.
//
// Row 11 slice A. Switch is an allowlisted vault `get` caller
// (`llm-plane`: operations ["list", "get"]; membership is operator config,
// like every caller). Slots are `switchyard.<vendor>` -- namespaced so a
// bare vendor id can never collide with another caller's slot. Presence
// (for readiness) comes from `list`, which never returns values; values
// come from `get`, only at the point of use (completion, discovery).
// No caching: rotation applies on the next call, and there is no second
// copy of a credential to go stale.
//
// Failure is refusal, never fallback: vault down, unconfigured, or
// refusing surfaces as missing_credential downstream -- the same shape as
// "no key", because from the caller's side there is no usable key.
const PREFIX = 'switchyard.';

export const slotFor = (vendorId) => `${PREFIX}${vendorId}`;

function creds() {
  return { url: process.env.VAULT_URL || '', token: process.env.SWITCH_VAULT_TOKEN || '' };
}

async function rpc(method, params) {
  const { url, token } = creds();
  if (!url || !token) {
    return { ok: false, reason: 'vault_unconfigured', because: 'set VAULT_URL and SWITCH_VAULT_TOKEN' };
  }
  const payload = JSON.stringify({ jsonrpc: '2.0', id: 1, method, params });
  const natsUrl = (process.env.MM_NATS_URL || '').trim();
  if (natsUrl) {
    try {
      const raw = await natsRequest(natsUrl, 'cpcp.vault.rpc', payload, token);
      if (!raw) {
        return { ok: false, reason: 'nats_unreachable',
                 because: 'MM_NATS_URL is set; HTTP is not a fallback' };
      }
      const body = JSON.parse(raw);
      if (!body || body.ok !== true) {
        return { ok: false, reason: (body && body.reason) || 'vault_refused',
                 because: (body && body.because) || {} };
      }
      return { ok: true, result: body.result };
    } catch (e) {
      return { ok: false, reason: 'nats_unreachable',
               because: String((e && e.message) || e) };
    }
  }
  let res;
  try {
    res = await fetch(`${url.replace(/\/$/, '')}/_cpcp/rpc`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: payload,
    });
  } catch (e) {
    return { ok: false, reason: 'vault_unreachable', because: String((e && e.message) || e) };
  }
  let body = null;
  try { body = await res.json(); } catch { body = null; }
  if (!res.ok || !body || body.ok !== true) {
    return { ok: false, reason: (body && body.reason) || 'vault_refused',
             because: (body && body.because) || { status: res.status } };
  }
  return { ok: true, result: body.result };
}

/** Vendor ids holding a vault slot. Presence only -- no values cross here. */
export async function keyNames() {
  const r = await rpc('vault.secret.list', {});
  if (!r.ok) return new Set();
  const items = (r.result && r.result.items) || [];
  return new Set(
    items.map((i) => i && i.name).filter((n) => typeof n === 'string' && n.startsWith(PREFIX))
      .map((n) => n.slice(PREFIX.length)),
  );
}

/** One key value, or null. Null means "no usable key", whatever the cause. */
export async function vaultKey(vendorId) {
  const r = await rpc('vault.secret.get', { name: slotFor(vendorId) });
  if (!r.ok) return null;
  const value = r.result && r.result.value;
  return typeof value === 'string' && value ? value : null;
}

/** Attach presence to a loaded state for readiness checks. */
export async function withKeys(state) {
  state.keyNames = await keyNames();
  return state;
}

/** Stdlib TCP NATS request-reply. Same protocol as mind_nats.py (ADR 0065). */
function natsRequest(url, subject, payload, token, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    let parsed;
    try { parsed = new URL(url); } catch (e) { reject(e); return; }
    const host = parsed.hostname || 'nats';
    const port = Number(parsed.port || 4222);
    const inbox = `_INBOX.${crypto.randomBytes(12).toString('hex')}`;
    const sock = net.connect({ host, port });
    let buf = Buffer.alloc(0);
    let handed = false;
    const fail = (err) => { if (handed) return; handed = true; try { sock.destroy(); } catch {} reject(err); };
    const ok = (val) => { if (handed) return; handed = true; try { sock.destroy(); } catch {} resolve(val); };
    sock.setTimeout(timeoutMs);
    sock.on('timeout', () => fail(new Error('nats timeout')));
    sock.on('error', fail);
    sock.on('data', (chunk) => {
      buf = Buffer.concat([buf, chunk]);
      while (buf.length) {
        if (buf.slice(0, 6).toString() === 'PING\r\n') {
          sock.write('PONG\r\n');
          buf = buf.slice(6);
          continue;
        }
        const s = buf.toString('binary');
        if (s.startsWith('INFO ')) {
          const nl = buf.indexOf('\r\n');
          if (nl < 0) return;
          buf = buf.slice(nl + 2);
          sock.write('CONNECT {"verbose":false,"pedantic":false,"tls_required":false,"name":"switch","lang":"javascript"}\r\n');
          sock.write(`SUB ${inbox} 1\r\n`);
          const body = Buffer.from(payload);
          if (token) {
            const hdr = Buffer.from(`NATS/1.0\r\nAuthorization: Bearer ${token}\r\n\r\n`);
            sock.write(`HPUB ${subject} ${inbox} ${hdr.length} ${hdr.length + body.length}\r\n`);
            sock.write(Buffer.concat([hdr, body, Buffer.from('\r\n')]));
          } else {
            sock.write(`PUB ${subject} ${inbox} ${body.length}\r\n`);
            sock.write(Buffer.concat([body, Buffer.from('\r\n')]));
          }
          continue;
        }
        if (s.startsWith('MSG ') || s.startsWith('HMSG ')) {
          const nl = buf.indexOf('\r\n');
          if (nl < 0) return;
          const line = buf.slice(0, nl).toString();
          const parts = line.split(' ');
          const size = Number(parts[parts.length - 1]);
          const rest = buf.slice(nl + 2);
          if (rest.length < size + 2) return;
          ok(rest.slice(0, size).toString());
          return;
        }
        const nl = buf.indexOf('\r\n');
        if (nl < 0) return;
        buf = buf.slice(nl + 2);
      }
    });
  });
}
