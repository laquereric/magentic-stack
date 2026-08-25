# SwitchYard.offline V1 — Local remedy (KISS) for hosted SwitchYard.online vulnerabilities

Author: Manus AI
Status: Concrete V1 design and runnable Chrome MV3 extension skeleton
Scope: A local, CL-based Chrome Manifest V3 extension implementing CPCP passthrough, random, and stage_router routing with on-device credentials; no LLMs, no hosted relay, no telemetry, and no arbitrary upstreams.

Executive summary
- SwitchYard.offline V1 is a self-contained Chrome MV3 extension that replaces the hosted SwitchYard.online routing surface with three deterministic local routing strategies: passthrough, random (weighted), and stage_router (deterministic stage hints). Credentials stay on-device; provider calls go directly to fixed origins over TLS. Prompts, completions, and content never traverse a hosted service.
- The architecture mirrors the CPCP contract surface but in a local, no-hosted path. A minimal core handles policy, routing, and direct egress; a Chrome overlay (popup) provides credential management; a small native-bridge is optional for OS keychain access but not required for V1.
- The deliverable includes a checked, locked-down MV3 package (dist/chrome) plus a delivery bundle containing design docs, SBOM, and hashes. The build verified manifest policy, tests, and integrity artifacts; placeholder external IDs are used for development and must be replaced with production IDs during release.

What SwitchYard.offline V1 implements
- Local CPCP surface: The contract uses the same surface names as the hosted CPCP (CID discovery, readiness, and RPC envelope), but all processing stays on-device. The local endpoint is invoked via Chrome messages, not a loopback HTTP listener.
- Three routing strategies, no content inspection: passthrough, random, and stage_router. No LLM classifier or escalation. Routing decisions are metadata-only and do not inspect user prompts or provider responses.
- Provider egress guard: A fixed-provider registry with explicit origin, path prefixes, and TLS with direct provider calls. No upstream SSRF or credential-forwarding touches host or user content beyond the provider payload.
- On-device credentials: chrome.storage.session is used by default to hold per-provider credentials for the current browser session only. Optional OS-keychain integration is available as a separate native bridge.
- Security-first manifest: Narrow host_permissions to three fixed origins, storage permission only, and a single approved external extension ID in externallly_connectable. No content_scripts, no broad host access, and a strict CSP.

Key design decisions mapping to vulnerabilities (Q1 analysis) [1] [2] [3] [6] [7]
- Credential handling (CRITICAL): On-device, per-provider keys stored in chrome.storage.session; no hosted keys. Optional native bridge exists but is not required for V1. Residual risk: browser compromise or local malware remains.
- Inline plaintext prompts/responses (CRITICAL): Content does not leave the device; only opaque provider payloads traverse the TLS path directly to the provider.
- Multi-tenant memory/side-channel (HIGH): Local, single-user extension boundary; no cross-tenant memory in a hosted process.
- Logs/telemetry/error retention (HIGH): No telemetry; never-raise contract; redacted errors only.
- TLS termination at hosted endpoint (HIGH): TLS terminates at the provider; end-to-end is preserved on-device to provider.
- Pre-alpha engine drift (HIGH): Local, pinned routing features; no external LLMs; SBOM and contract digest guard drift.
- Upstream egress / SSRF / credential-forwarding (HIGH/CRITICAL): Fixed-origin, explicit path-prefix checks; no credentials forwarded to arbitrary hosts; headers constructed on-device.
- Public contract/discovery drift (HIGH): CID digest and local contract surface pinned in cid.json; explicit releases required for digest changes.

References for policy and routing concepts
- Chrome permissions, host_permissions, and enterprise deployment options [1] [8]
- Chrome storage API for ephemeral session storage [2]
- Native messaging as optional OS bridge for credentials [3]
- NVIDIA SwitchYard and stage-router concepts (for framing, not wholesale copying) [6] [7]
- Public CPCP reference (rails-cpcp) for contract shape and never-raise envelope precedent [4]
- Public boundary patterns (mm-local-ai-boundary) for a narrow MV3 permission contract [5]

Component architecture (high-level)
- shared core (SwitchYard.offline-V1/shared):
  - cid.template.json: local CPCP contract template; generated CID is stamped at build time via build/generate-cid.mjs.
  - contract.js: CPCP envelope validation and runtime message routing helpers.
  - router.js: content-blind selectors for passthrough, random, and stage_router; deterministic behavior; no content-inspection.
  - egress.js: strict provider egress guard; origin/path validation; header construction is performed locally.
  - errors.js: never-raise error helpers and safe messages.
  - routes.js: fixed provider registry and static route definitions (passthrough, random, stage_router).
- chrome overlay (SwitchYard.offline-V1/chrome):
  - manifest.json: MV3 manifest with module service worker; narrow host permissions; a single approved external extension ID; storage permission only; CSP restricted to provider origins.
  - service-worker.js: main broker; message boundary enforcement; dispatch to CPCP handlers and egress
  - credential-store.js: session-scoped credential storage; initialization; getters/setters; API guardrails
  - popup.html & popup.css & popup.js: compact UI to set tokens per provider and display status; tokens stay in session only and are cleared after use
  - assets: placeholder for UI assets
- build and delivery (SwitchYard.offline-V1/build):
  - generate-cid.mjs: deterministic CID digest computation from cid.template.json
  - build.mjs: copies shared/chrome into dist and pins the externals to the approved client extension ID; updates manifest accordingly
  - check-manifest.mjs: strict manifest gate enforcing MV3 constraints and absence of forbidden features
  - generate-sbom.mjs: CycloneDX SBOM for auditable supply chain visibility
  - package.mjs: packaging step to zip up dist and generate SHA256SUMS
  - clean.mjs: removes generated artifacts for fresh builds
- tests (SwitchYard.offline-V1/tests):
  - router.test.mjs: unit tests for passthrough, random, stage_router
  - egress.test.mjs: direct egress tests with mocked provider fetch
  - contract.test.mjs: CPCP envelope validation tests
  - manifest.test.mjs: source manifest policy gate tests
- docs: threat model, permission contract, release checklist, client integration notes
- delivery: a single archive containing all artifacts is produced (SwitchYard.offline-V1-delivery.zip) for distribution

Concrete design artifacts (files created or updated)
- SwitchYard.offline-V1-Design.md: architecture overview, module responsibilities, and design decisions.
- Share core: shared/{errors.js, routes.js, router.js, egress.js, contract.js, generated-cid.js, cid.template.json}
- Chrome overlay: chrome/{manifest.json, service-worker.js, credential-store.js, popup.html, popup.css, popup.js}
- Build and test: build/{generate-cid.mjs, build.mjs, check-manifest.mjs, generate-sbom.mjs, package.mjs, clean.mjs}, tests, SBOM, ZIP artifact
- Delivery: SwitchYard.offline-V1-delivery.zip plus verification records and verifiable SHA256 sums

How to install and run locally (KISS)
- Build the package using Node.js 20+ and zip utility: npm install; npm run build
- In Chrome, open chrome://extensions, enable Developer mode, Load unpacked, and select the dist/chrome folder inside SwitchYard.offline-V1-delivery
- Use the SwitchYard.offline MV3 popup to add per-provider tokens (OpenAI, Anthropic, NVIDIA) for the current session; tokens are stored in chrome.storage.session and cleared when the session ends or the extension is disabled
- The local CPCP surface is accessible through the extension messaging: call chrome.runtime.sendMessage with cpcpPath /_cpcp/rpc and a JSON-RPC-LD envelope
- Production guidance: replace the placeholder extension ID with your production 32-char ID (only the a-p alphabet allowed) and rebuild; do not ship with the placeholder to production

Sustainability notes
- This V1 is a deliberately narrow, no-LLM topography designed to fix the top vulnerabilities without introducing new risks. Future V2 could introduce a local LLM, further policy gates, or more sophisticated boundary controls; when/if that happens, it should be designed with threat modeling and a separate release plan.

References and sources used in crafting this design
- Chrome Extensions: Declare permissions [1], Storage API [2], Native messaging [3]
- Public CPCP precedent: rails-cpcp [4]
- Local boundary model: mm-local-ai-boundary [5]
- NVIDIA SwitchYard routing docs (overview) [6], Stage-router routing [7]
- Chrome enterprise publishing options [8]

References
- [1] Chrome Developers — Declare permissions. https://developer.chrome.com/docs/extensions/develop/concepts/declare-permissions
- [2] Chrome — chrome.storage API. https://developer.chrome.com/docs/extensions/reference/api/storage
- [3] Chrome — Native messaging. https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging
- [4] laquereric/rails-cpcp. https://github.com/laquereric/rails-cpcp
- [5] laquereric/mm-local-ai-boundary. https://github.com/laquereric/mm-local-ai-boundary
- [6] NVIDIA-NeMo/Switchyard — Routing overview. https://github.com/NVIDIA-NeMo/Switchyard/blob/main/docs/routing_algorithms/overview.md
- [7] NVIDIA-NeMo/Switchyard — Stage-router routing. https://github.com/NVIDIA-NeMo/Switchyard/blob/main/docs/routing_algorithms/stage_router_routing.md
- [8] Chrome Enterprise publishing options. https://developer.chrome.com/docs/webstore/cws-enterprise

Delivery artifacts and their locations
- SwitchYard.offline-V1-delivery.zip: delivery bundle containing the Chrome MV3 package, design docs, SBOM, and verification records
- SwitchYard.offline-V1-Design.md: architectural design document
- research_notes.md: research findings and decisions throughout the planning process
- SBOM.cdx.json, SHA256SUMS: integrity and supply chain artifacts
- VERIFICATION.md: build and verification results including the local CID digest
- Verifiable manifest and test results are written into the dist folder during the build

If you’d like, I can provide a compact PDF version of this final design and the delivery manifest, or package a separate release note that you can attach to your repository.”