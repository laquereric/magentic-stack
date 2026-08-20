// runtimes/switch/ui/ui.js -- config surface for LLM sources.
// A stored key is NEVER sent back to the browser; we only learn ready:true.
const $ = (id) => document.getElementById(id);
let state = { active: null, sources: [], allowedOrigins: [] };

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
    if (result && result.sources) { state = { ...state, ...result }; render(); }
    msg(okText || '');
    return result;
  } catch (e) {
    msg(e.message, 'bad');
    return null;
  }
}

function tag(text, cls) {
  const s = document.createElement('span');
  s.className = 'tag' + (cls ? ' ' + cls : '');
  s.textContent = text;
  return s;
}

function card(s) {
  const active = s.id === state.active;
  const el = document.createElement('div');
  el.className = 'src' + (active ? ' active' : '');

  const row = document.createElement('div');
  row.className = 'row';
  const name = document.createElement('span');
  name.className = 'name';
  name.textContent = s.id;
  row.append(name, tag(s.kind));
  if (s.kind === 'local') row.append(tag('no egress', 'ok'));
  row.append(s.ready ? tag('ready', 'ok') : tag('key not set', 'off'));
  if (active) row.append(tag('active', 'ok'));

  const origin = document.createElement('div');
  origin.className = 'origin';
  origin.textContent = s.origin + (s.model ? '  ·  ' + s.model : '');

  const ctl = document.createElement('div');
  ctl.className = 'ctl';

  if (s.needsKey) {
    const key = document.createElement('input');
    key.type = 'password';
    key.autocomplete = 'off';
    key.placeholder = s.ready ? 'key set — paste a new one to replace' : 'paste API key';
    const save = document.createElement('button');
    save.textContent = 'Save key';
    save.onclick = () => key.value
      && act(() => api('/api/sources', { id: s.id, key: key.value }), `${s.id}: key saved`)
        .then(() => { key.value = ''; });
    ctl.append(key, save);
    if (s.ready) {
      const clear = document.createElement('button');
      clear.textContent = 'Clear';
      clear.onclick = () => act(() => api('/api/sources', { id: s.id, key: '' }), `${s.id}: key cleared`);
      ctl.append(clear);
    }
  }

  const model = document.createElement('input');
  model.type = 'text';
  model.value = s.model || '';
  model.placeholder = 'model';
  model.onchange = () => act(() => api('/api/sources', { id: s.id, model: model.value }), `${s.id}: model set`);
  ctl.append(model);

  const use = document.createElement('button');
  use.textContent = active ? 'In use' : 'Use this source';
  use.className = active ? '' : 'primary';
  use.disabled = active || (s.needsKey && !s.ready);
  use.onclick = () => act(() => api('/api/sources', { active: s.id }), `active source is now ${s.id}`);

  const test = document.createElement('button');
  test.textContent = 'Test';
  test.disabled = s.needsKey && !s.ready;
  test.onclick = async () => {
    test.disabled = true;
    msg(`testing ${s.id}…`);
    const r = await act(() => api('/api/test', { id: s.id }));
    if (r) msg(r.ok ? `${s.id}: responded ok` : `${s.id}: ${(r.detail && (r.detail.because || r.detail.reason)) || 'no response'}`, r.ok ? '' : 'bad');
    test.disabled = false;
  };

  ctl.append(use, test);
  el.append(row, origin, ctl);
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
  name.textContent = 'auto';
  row.append(name, tag('router'), tag('local decision', 'ok'));
  if (active) row.append(tag('active', 'ok'));

  const origin = document.createElement('div');
  origin.className = 'origin';
  origin.textContent = `the ${state.localId} model picks a source per request — your prompt stays on the device to decide`;

  const ctl = document.createElement('div');
  ctl.className = 'ctl';
  const use = document.createElement('button');
  use.textContent = active ? 'In use' : 'Use auto routing';
  use.className = active ? '' : 'primary';
  use.disabled = active;
  use.onclick = () => act(() => api('/api/sources', { active: state.auto }), 'auto routing enabled');
  ctl.append(use);

  el.append(row, origin, ctl);
  return el;
}

function render() {
  const list = $('list');
  list.textContent = '';
  list.append(autoCard());
  for (const s of state.sources) list.append(card(s));
  $('allow').textContent = state.allowedOrigins.join('  ');
}

act(async () => {
  state = await api('/api/sources');
  render();
  return null;
});
