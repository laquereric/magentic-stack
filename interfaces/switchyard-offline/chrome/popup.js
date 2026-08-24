// chrome/popup.js — set/clear per-provider session tokens + status.

const PROVIDERS = ['openai', 'anthropic', 'nvidia'];

function send(msg) {
  return new Promise((resolve) => {
    chrome.runtime.sendMessage(msg, (res) => {
      if (chrome.runtime.lastError) {
        resolve({
          ok: false,
          error: {
            reason: 'runtime',
            because: chrome.runtime.lastError.message,
          },
        });
        return;
      }
      resolve(res);
    });
  });
}

function setMsg(text) {
  const el = document.getElementById('msg');
  if (el) el.textContent = text || '';
}

async function refreshStatus() {
  const res = await send({ type: 'cred.status' });
  if (!res || !res.ok) {
    setMsg((res && res.error && res.error.because) || 'status failed');
    return;
  }
  const providers = res.result.providers || {};
  for (const id of PROVIDERS) {
    const el = document.querySelector(`[data-status="${id}"]`);
    if (!el) continue;
    const on = !!providers[id];
    el.textContent = on ? 'token set (session)' : 'no token';
    el.className = `status ${on ? 'on' : 'off'}`;
  }
}

function wire() {
  document.querySelectorAll('[data-set]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-set');
      const input = document.getElementById(`tok-${id}`);
      const token = input ? input.value.trim() : '';
      if (!token) {
        setMsg('enter a token first');
        return;
      }
      const res = await send({ type: 'cred.set', provider: id, token });
      if (input) input.value = '';
      setMsg(res.ok ? `${id} token stored in session` : (res.error && res.error.because) || 'set failed');
      await refreshStatus();
    });
  });

  document.querySelectorAll('[data-clear]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-clear');
      const res = await send({ type: 'cred.clear', provider: id });
      setMsg(res.ok ? `${id} cleared` : (res.error && res.error.because) || 'clear failed');
      await refreshStatus();
    });
  });

  document.getElementById('refresh')?.addEventListener('click', () => refreshStatus());
  document.getElementById('clear-all')?.addEventListener('click', async () => {
    const res = await send({ type: 'cred.clearAll' });
    setMsg(res.ok ? 'all session tokens cleared' : (res.error && res.error.because) || 'clear failed');
    await refreshStatus();
  });
}

wire();
refreshStatus();
