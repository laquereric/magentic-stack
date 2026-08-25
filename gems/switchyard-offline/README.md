# app-switchyard-offline &mdash; **SwitchYard.offline**

**A local, content-blind LLM router.** SwitchYard.offline is a Chrome MV3 extension that is
**nothing but a CPCP wrapper around NVIDIA SwitchYard's three no-inspection routing features**
&mdash; `passthrough`, `random`, `stage_router` &mdash; running **entirely on your device**.

It is the local remedy for the hosted [switchyard.online](https://switchyard.online) vulnerabilities
(`docs/VULNERABILITY_ANALYSIS.md`): your **provider credentials and prompts never leave your machine**.
SwitchYard.offline runs the inline proxy locally, stores per-provider keys in `chrome.storage.session`
only, and calls the upstream provider **directly** &mdash; so TLS is end-to-end (you &rarr; provider),
with no hosted endpoint decrypting your content.

## V1 scope (KISS)
- **3 strategies, content-blind:** passthrough, random (weighted), stage_router (progress-signal hints). **No LLM inspection of your prompts.**
- **No local LLM** for routing intelligence in V1. (A future V2 *could* use a local LLM to guide routing &mdash; foreshadowed, not committed.)
- **On-device credentials**, session-scoped; never transmitted off-device.
- **Narrow egress:** `host_permissions` + CSP allowlist the provider origins only. No arbitrary upstreams.
- **Same CPCP surface** as switchyard.online (CID-grounded `/_cpcp`, never-raise) &mdash; clients/threedot point at the local extension instead of the hosted service.

## Layout (app-browser-plugin model)
```
shared/          browser-agnostic core: router, routes, egress, contract, errors, cid.template.json
chrome/          MV3 overlay: manifest.json, service-worker.js, credential-store.js, popup
local-listener/  loopback HTTP (127.0.0.1:8789) for any-language OpenAI base_url clients
build/           generate-cid, build, check-manifest, generate-sbom, package, clean
tests/           router + manifest + listener
docs/            DESIGN.md, VULNERABILITY_ANALYSIS.md
```

## Build / test (plain Node, zero deps)

```bash
npm run build          # generate-cid + assemble dist/chrome + check-manifest
npm test               # node --test (router + manifest + listener)
npm run check-manifest
npm run package        # zip + SHA256SUMS + SBOM
```

### Chrome MV3 extension

Load unpacked: Chrome → Extensions → Developer mode → `dist/chrome`.

Local CPCP via messaging:

```js
chrome.runtime.sendMessage({
  cpcpPath: '/_cpcp/rpc',
  method: 'switchyard.route',
  params: { strategy: 'passthrough', provider: 'openai', dryRun: true }
});
```

### Run the local listener

For any language client that wants an OpenAI-compatible `base_url` (as site docs describe):

```bash
# optional: export SWITCHYARD_LOCAL_TOKEN=…  SWITCHYARD_OPENAI_KEY=…
# or put keys in ~/.switchyard-offline/keys.json (chmod 600)
npm run listen          # http://127.0.0.1:8789  (SWITCHYARD_LOCAL_PORT to override)
```

- **Bind:** `127.0.0.1` only (never `0.0.0.0`)
- **Auth:** every request needs header `X-SwitchYard-Token` (env `SWITCHYARD_LOCAL_TOKEN` or auto file `~/.switchyard-offline/token`)
- **Abuse guard:** requests with `Origin` or `Referer` are **rejected** (no browser CORS)
- **Endpoints:**
  - `GET /_cpcp/cid.json`
  - `POST /_cpcp/rpc`
  - `POST /v1/chat/completions` (OpenAI shape → allowlisted provider via shared/router+egress)
  - `POST /v1/messages` (Anthropic shape)
- **Routing metadata** (content-blind headers): `X-SwitchYard-Strategy`, `X-SwitchYard-Provider`, `X-SwitchYard-Stage`

```bash
TOKEN=$(cat ~/.switchyard-offline/token)
curl -sS -H "X-SwitchYard-Token: $TOKEN" http://127.0.0.1:8789/_cpcp/cid.json
```

The MV3 extension path is unchanged for in-browser JS (`chrome.runtime` messaging).

Upstream engine: **NVIDIA NeMo Switchyard** (pre-alpha) &mdash; github.com/NVIDIA-NeMo/Switchyard.
Design: `docs/DESIGN.md`. Private; Apache-2.0.
