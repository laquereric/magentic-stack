// Gate 5 - offline boundary: "no prompt leaves your device".
// Drives SwitchYard.offline's real egress gate (gems/switchyard-offline/shared)
// and proves the ONLY network destinations are the allowlisted provider origins,
// reached only WITH an on-device credential - everything else is denied BEFORE any
// fetch, so no bytes (prompt) egress on a denied path.
//
// Full-browser WebDriver-BiDi egress capture (extension loaded) is a future
// enhancement; this drives the same egress authority deterministically in CI.
import { validateTarget, egress, isAllowedOrigin } from '../../gems/switchyard-offline/shared/egress.js';
import { ALLOWED_ORIGINS } from '../../gems/switchyard-offline/shared/routes.js';
import { writeFileSync, mkdirSync } from 'node:fs';

const checks = [];
function check(name, ok, detail = '') {
  checks.push({ assertion: name, ok: !!ok, detail: String(detail).slice(0, 200) });
  console.log((ok ? '  ok   ' : '  FAIL ') + name + ' :: ' + String(detail).slice(0, 160));
  return !!ok;
}
function spyFetch() {
  const calls = [];
  const fn = async (url) => { calls.push(String(url)); return { ok: true, status: 200, async text() { return '{}'; } }; };
  fn.calls = calls;
  return fn;
}

// 1) allowlist is exactly the known providers, all https
check('allowlist-https-only', ALLOWED_ORIGINS.length >= 1 && ALLOWED_ORIGINS.every(o => o.startsWith('https://')), ALLOWED_ORIGINS.join(','));

// 2) deny: unknown provider / cross-origin injection / traversal / non-allowlisted prefix
check('deny-unknown-provider', validateTarget('evil', '/v1/x').ok === false, 'unknown provider');
check('deny-cross-origin-injection', validateTarget('openai', 'https://evil.example/v1/').ok === false, 'absolute url in path');
check('deny-path-traversal', validateTarget('openai', '/v1/../../etc/passwd').ok === false, 'traversal');
check('deny-non-allowlisted-prefix', validateTarget('openai', '/admin/keys').ok === false, 'prefix not /v1/');

// 3) allow: a valid provider path resolves to an allowlisted https origin ONLY
const good = validateTarget('anthropic', '/v1/messages');
check('allow-valid-provider-origin', good.ok === true && isAllowedOrigin(good.result.url.origin) && good.result.url.protocol === 'https:', good.ok ? good.result.url.origin : good.error);

// 4) NO EGRESS ON DENY - a denied target never calls fetch (no prompt leaves)
const spy1 = spyFetch();
const r1 = await egress({ providerId: 'evil', path: '/v1/x', token: 't', body: { messages: [{ role: 'user', content: 'SECRET PROMPT' }] }, fetchImpl: spy1 });
check('denied-target-zero-egress', r1.ok === false && spy1.calls.length === 0, `ok=${r1.ok} fetchCalls=${spy1.calls.length}`);

// 5) NO EGRESS WITHOUT ON-DEVICE CREDENTIAL - valid target but no token never fetches
const spy2 = spyFetch();
const r2 = await egress({ providerId: 'openai', path: '/v1/chat/completions', body: { messages: [{ role: 'user', content: 'SECRET PROMPT' }] }, fetchImpl: spy2 });
check('no-credential-zero-egress', r2.ok === false && spy2.calls.length === 0, `reason=${r2.error && r2.error.reason} fetchCalls=${spy2.calls.length}`);

// 6) EGRESS ONLY TO ALLOWLIST - a valid call fetches EXACTLY one allowlisted origin
const spy3 = spyFetch();
const r3 = await egress({ providerId: 'openai', path: '/v1/chat/completions', token: 'on-device-key', body: { messages: [{ role: 'user', content: 'hi' }] }, fetchImpl: spy3 });
const onlyAllowlisted = spy3.calls.length === 1 && isAllowedOrigin(new URL(spy3.calls[0]).origin);
check('egress-only-to-allowlist', r3.ok === true && onlyAllowlisted, spy3.calls.join(','));

const ok = checks.every(c => c.ok);
const nowIso = new Date(0).toISOString(); // deterministic placeholder ok; CI stamps via env if needed
const report = {
  gate: 'offline-boundary', status: ok ? 'pass' : 'fail',
  subject: process.env.GITHUB_SHA || 'LOCAL',
  policy: 'no prompt leaves your device: egress denied before fetch except to allowlisted provider origins with an on-device credential',
  started_at: process.env.MS_TS || nowIso, finished_at: process.env.MS_TS || nowIso,
  tool: 'tooling/offline/offline_boundary_test.mjs + gems/switchyard-offline/shared/egress.js',
  assertions: checks, digests: {},
};
mkdirSync('evidence', { recursive: true });
writeFileSync('evidence/offline-boundary.json', JSON.stringify(report, null, 2));
const fails = checks.filter(c => !c.ok).map(c => c.assertion);
if (fails.length) { console.error('GATE 5 FAIL: ' + fails.join(', ')); process.exit(1); }
console.log(`offline boundary (Gate 5): OK (${checks.length} checks)`); process.exit(0);
