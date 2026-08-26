---
id: "0019"
title: The model router is content-blind and holds the credential
status: accepted
date: 2026-08-26
subject_kind: gem
subject: switchyard-offline
components: [switchyard-offline]
paths:
  - gems/switchyard-offline/shared
  - gems/switchyard-offline/local-listener
  - runtimes/switch
enforced_by:
  - gems/switchyard-offline/tests/listener.test.mjs
  - gems/switchyard-offline/tests/router.test.mjs
  - runtimes/switch/tests/openrouter.test.mjs
supersedes: null
superseded_by: null
---

## Context

An agent that needs a model needs a credential. Giving it one puts a raw secret
in the agent container and lets the agent egress directly, which ends
default-deny egress as a property of the system.

## Decision

A routing plane owns the credential and decides local-or-remote under policy.
The agent asks for a completion and holds nothing.

- **Content-blind.** Routing reads headers, never the body. A router that reads
  the prompt to decide where to send it has read the prompt.
- **Egress is allowlisted and TLS-only.** `validateTarget` refuses any origin
  outside the frozen list, and any non-`https:` target.
- **Local is a separate class, not a widened allowlist.** A local model bypasses
  the egress gate entirely, because nothing leaves the device and there is no
  egress decision to make. Admitting `http://ollama:11434` to the allowlist
  instead would weaken the remote guarantee to buy a local one.
- **Two ports.** Data plane is pod-internal and rejects any request carrying an
  `Origin` header; the config UI is a separate published port that cannot reach
  the proxy path.
- **Pinning is a header** (`X-SwitchYard-Source: vendor:model`), not the body's
  `model` field, so the routing decision does not depend on parsing the payload.

## Consequences

- MIND runs with `api_key="switchyard-local"` and no provider secret.
- Keys enter only through the UI over an SSH tunnel; no agent places a key.
- Routing must resolve models against **discovered vendor state**, not the
  static seed catalog. Validating a pin against the catalog made every
  discovered model unpinnable -- a real defect, found when OpenRouter arrived
  with 404 models and none selectable, and equally true of Fireworks before it.
