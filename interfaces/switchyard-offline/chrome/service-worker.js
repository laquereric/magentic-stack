// chrome/service-worker.js — MV3 module worker: local CPCP surface over messaging.
// /_cpcp/rpc + /_cpcp/cid.json via chrome.runtime.onMessage + onMessageExternal.
// Never-raise; dispatch to router + egress.

import { handleCpcp } from './contract.js';
import * as creds from './credential-store.js';
import { CID as GENERATED_CID } from './generated-cid.js';

const CID = GENERATED_CID || {
  cid: 'cid:switchyard.offline:v1',
  note: 'generated-cid missing — run build/generate-cid.mjs',
};

function neverRaise(handler) {
  return async (...args) => {
    try {
      return await handler(...args);
    } catch (e) {
      const name = e && e.name ? e.name : 'Error';
      const msg = e && e.message ? String(e.message).slice(0, 200) : 'unknown';
      return { ok: false, error: { reason: 'handler_error', because: `${name}: ${msg}` } };
    }
  };
}

async function dispatchMessage(msg) {
  if (!msg || typeof msg !== 'object') {
    return { ok: false, error: { reason: 'invalid_message', because: 'message must be an object' } };
  }

  // Credential management (popup)
  if (msg.type === 'cred.set') {
    return creds.setToken(msg.provider, msg.token);
  }
  if (msg.type === 'cred.clear') {
    return creds.clearToken(msg.provider);
  }
  if (msg.type === 'cred.clearAll') {
    return creds.clearAll();
  }
  if (msg.type === 'cred.status') {
    return creds.status();
  }

  // Local CPCP surface
  const cpcpPath = msg.cpcpPath || msg.path || (msg.type === 'cpcp' ? msg.cpcpPath : null);
  if (cpcpPath || msg.type === 'cpcp' || msg.method) {
    return handleCpcp({
      cpcpPath: cpcpPath || '/_cpcp/rpc',
      envelope: msg.envelope || msg,
      cid: CID,
      getToken: (providerId) => creds.getToken(providerId),
    });
  }

  return {
    ok: false,
    error: {
      reason: 'unknown_message',
      because: 'expected cpcpPath /_cpcp/rpc|/ _cpcp/cid.json or cred.*',
    },
  };
}

const onMsg = neverRaise(dispatchMessage);

if (typeof chrome !== 'undefined' && chrome.runtime) {
  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    onMsg(message).then(sendResponse);
    return true; // async
  });

  if (chrome.runtime.onMessageExternal) {
    chrome.runtime.onMessageExternal.addListener((message, _sender, sendResponse) => {
      onMsg(message).then(sendResponse);
      return true;
    });
  }
}

// Export for tests
export { dispatchMessage, onMsg, CID };
