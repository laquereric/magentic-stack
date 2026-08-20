// runtimes/switch/ui/ui.js -- vendors, their models, and what routing may pick.
// A stored key is NEVER sent back here; we only ever learn ready:true.
const $ = (id) => document.getElementById(id);
let state = { active: null, auto: 'auto', routerPin: null, vendors: [], allowedOrigins: [] };

function msg(text, tone) {
  const el = $('msg');
  el.textContent = text || '';
  el.style.color = tone === 'bad' ? '#c0392b' : '';
}

async function api(path, body) {
  const res = await fetch(path, body
    ? { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }
    : undefined);
  const json = await res.json();
  if (!json.ok) throw new Error(json.because || json.reason || 'request failed');
  return json.result;
}

async function act(fn, okText) {
  try {
    const result = await fn();
    if (result && result.vendors) { state = { ...state, ...result }; render(); }
    msg(okText || '');
    return result;
  } catch (e) { msg(e.message, 'bad'); return null; }
}

function tag(text, cls) {
  const s = document.createElement('span');
  s.className = 'tag' + (cls ? ' ' + cls : '');
  s.textContent = text;
  return s;
}

function price(m) {
  if (m.in == null || m.out == null) return 'price unknown — set it';
  if (m.in === 0 && m.out === 0) return 'free';
  return `$${m.in}/M in · $${m.out}/M out`;
}

function modelRow(v, m) {
  const el = document.createElement('div');
  el.className = 'model' + (state.active === m.pin ? ' active' : '');

  const row = document.createElement('div');
  row.className = 'row';
  const name = document.createElement('span');
  name.className = 'mname';
  name.textContent = m.id;
  row.append(name, tag(price(m), m.in === 0 ? 'ok' : ''));
  if (!m.tools) row.append(tag(m.toolsVerified ? 'no tool calling (proven)' : 'no tool calling', 'off'));
  else if (m.toolsVerified) row.append(tag('tools proven', 'ok'));
  else row.append(tag('tools assumed', 'off'));
  if (state.routerPin === m.pin) row.append(tag('router', 'ok'));
  if (state.active === m.pin) row.append(tag('pinned', 'ok'));
  if (!m.enabled) row.append(tag('disabled', 'off'));

  const ctl = document.createElement('div');
  ctl.className = 'ctl';

  const pin = document.createElement('button');
  pin.textContent = state.active === m.pin ? 'Pinned' : 'Pin';
  pin.title = 'Send every request to this model';
  pin.disabled = !v.ready || state.active === m.pin || !m.enabled;
  pin.onclick = () => act(() => api('/api/sources', { active: m.pin }), `pinned ${m.pin}`);

  const router = document.createElement('button');
  router.textContent = state.routerPin === m.pin ? 'Routing' : 'Use as router';
  router.title = 'Let this model choose which other model answers';
  router.disabled = !v.ready || state.routerPin === m.pin || !m.enabled;
  router.onclick = () => act(() => api('/api/sources', { routerPin: m.pin }), `router is ${m.pin}`);

  const toggle = document.createElement('button');
  toggle.textContent = m.enabled ? 'Disable' : 'Enable';
  toggle.title = 'Whether auto routing may choose this model';
  toggle.onclick = () => act(() => api('/api/sources', { pin: m.pin, enabled: !m.enabled }),
    `${m.id} ${m.enabled ? 'disabled' : 'enabled'}`);

  const test = document.createElement('button');
  test.textContent = 'Test';
  test.disabled = !v.ready;
  test.onclick = async () => {
    test.disabled = true; msg(`testing ${m.pin}…`);
    const r = await act(() => api('/api/test', { pin: m.pin }));
    if (r) msg(r.ok ? `${m.pin}: responded ok`
      : `${m.pin}: ${(r.detail && (r.detail.because || r.detail.reason)) || 'no response'}`, r.ok ? '' : 'bad');
    test.disabled = false;
  };

  ctl.append(pin, router, toggle, test);
  el.append(row, ctl);
  return el;
}

function vendorCard(v) {
  const el = document.createElement('div');
  el.className = 'src';

  const row = document.createElement('div');
  row.className = 'row';
  const name = document.createElement('span');
  name.className = 'name';
  name.textContent = v.label;
  row.append(name, tag(v.kind));
  if (v.kind === 'local') row.append(tag('no egress', 'ok'));
  row.append(v.ready ? tag('ready', 'ok') : tag('key not set', 'off'));

  const origin = document.createElement('div');
  origin.className = 'origin';
  origin.textContent = v.origin;

  el.append(row, origin);

  if (v.needsKey) {
    const ctl = document.createElement('div');
    ctl.className = 'ctl';
    const key = document.createElement('input');
    key.type = 'password'; key.autocomplete = 'off';
    key.placeholder = v.ready ? 'key set — paste a new one to replace' : 'paste API key';
    const save = document.createElement('button');
    save.textContent = 'Save key';
    save.onclick = () => key.value
      && act(() => api('/api/sources', { vendor: v.id, key: key.value }), `${v.id}: key saved`)
        .then(() => { key.value = ''; });
    ctl.append(key, save);
    if (v.ready) {
      const clear = document.createElement('button');
      clear.textContent = 'Clear';
      clear.onclick = () => act(() => api('/api/sources', { vendor: v.id, key: '' }), `${v.id}: key cleared`);
      ctl.append(clear);
    }
    el.append(ctl);
  }

  const refresh = document.createElement('div');
  refresh.className = 'ctl';
  const rb = document.createElement('button');
  rb.textContent = 'Refresh models';
  rb.title = 'Ask the vendor which models this key opens';
  rb.disabled = !v.ready;
  rb.onclick = async () => {
    rb.disabled = true; msg(`asking ${v.id} for its models…`);
    const r = await act(() => api('/api/refresh', { vendor: v.id }));
    if (r) msg(r.ok ? `${v.id}: ${r.count} models`
      : `${v.id}: ${(r.detail && (r.detail.because || r.detail.reason)) || 'refresh failed'}`, r.ok ? '' : 'bad');
    rb.disabled = false;
  };
  refresh.append(rb);

  const vb = document.createElement('button');
  vb.textContent = 'Verify tools';
  vb.title = 'Ask each enabled model to make one tool call. Costs one small request per model.';
  vb.disabled = !v.ready;
  vb.onclick = async () => {
    vb.disabled = true;
    msg(`probing ${v.id} models for tool support… (one request each)`);
    const r = await act(() => api('/api/verify-tools', { vendor: v.id }));
    if (r) {
      const proven = r.results.filter((x) => x.verified).length;
      const capable = r.results.filter((x) => x.verified && x.tools).length;
      msg(`${v.id}: ${capable} of ${proven} proven models can tool-call` +
          (proven < r.results.length ? ` (${r.results.length - proven} inconclusive)` : ''));
    }
    vb.disabled = false;
  };
  refresh.append(vb);

  if (!v.discovered && v.ready) refresh.append(tag('showing catalog defaults, not this key', 'off'));
  el.append(refresh);

  for (const m of v.models) el.append(modelRow(v, m));
  return el;
}

function autoCard() {
  const active = state.active === state.auto;
  const el = document.createElement('div');
  el.className = 'src' + (active ? ' active' : '');

  const row = document.createElement('div');
  row.className = 'row';
  const name = document.createElement('span');
  name.className = 'name';
  name.textContent = 'auto routing';
  row.append(name, tag('router'));
  if (active) row.append(tag('active', 'ok'));

  const origin = document.createElement('div');
  origin.className = 'origin';
  origin.textContent = state.routerPin
    ? `capability and price decide; ${state.routerPin} breaks the tie — it sees a prompt excerpt`
    : 'capability and price decide, with no model in the loop (no router set)';

  const ctl = document.createElement('div');
  ctl.className = 'ctl';
  const use = document.createElement('button');
  use.textContent = active ? 'In use' : 'Use auto routing';
  use.className = active ? '' : 'primary';
  use.disabled = active;
  use.onclick = () => act(() => api('/api/sources', { active: state.auto }), 'auto routing enabled');
  ctl.append(use);
  if (state.routerPin) {
    const clear = document.createElement('button');
    clear.textContent = 'Clear router';
    clear.onclick = () => act(() => api('/api/sources', { routerPin: null }), 'router cleared');
    ctl.append(clear);
  }

  el.append(row, origin, ctl);
  return el;
}

function render() {
  const list = $('list');
  list.textContent = '';
  list.append(autoCard());
  for (const v of state.vendors) list.append(vendorCard(v));
  $('allow').textContent = state.allowedOrigins.join('  ');
}

act(async () => { state = await api('/api/sources'); render(); return null; });
