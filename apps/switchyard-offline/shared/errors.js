// SwitchYard.offline shared/errors.js — never-raise safe error helpers (no content leakage).

/** Build a redacted never-raise error object. */
export function fail(reason, because, meta = undefined) {
  const err = {
    ok: false,
    error: {
      reason: String(reason || 'error'),
      because: String(because || 'unspecified'),
    },
  };
  if (meta && typeof meta === 'object') {
    err.error.meta = meta;
  }
  return err;
}

/** Success envelope. */
export function ok(result, meta = undefined) {
  const out = { ok: true, result };
  if (meta && typeof meta === 'object') {
    out.meta = meta;
  }
  return out;
}

/** Map thrown values to redacted envelopes (never leak stack/prompt). */
export function fromThrown(e, reason = 'handler_error') {
  const name = e && e.name ? String(e.name) : 'Error';
  const msg = e && e.message ? String(e.message).slice(0, 200) : 'unknown';
  return fail(reason, `${name}: ${msg}`);
}
