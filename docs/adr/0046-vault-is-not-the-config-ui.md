---
id: "0046"
title: VAULT is a separate container from CONFIG-ADMIN; the published port is not the boundary
status: accepted
date: 2026-08-30
subject_kind: topology
subject: SWITCH decomposition
components: [switch, vault, config-admin, llm-plane]
paths:
  - runtimes/switch
  - runtimes/mind-pod/docker-compose.yml
enforced_by:
  - runtimes/mind-pod/docker-compose.yml
  - tooling/compose/check_role_routes.py
supersedes: null
superseded_by: null  # amended in part by 0047
---

# VAULT is not the config UI

## The question this closes

`docs/reviews/2026-08-30g` recommended splitting today's single `switch`
process into an LLM data plane, a `config-admin` surface, and a narrow `vault`.
The operator asked whether `vault` and `config-admin`, being co-resident on one
published port, are therefore one container.

## Decision

**Three containers out of today's one, and `vault` is not `config-admin`.**

| Target | Owns | Host exposure |
|---|---|---|
| `llm-plane` | routing, provider adaptation, translation, data-plane health (today's 8789) | none; pod-internal |
| `config-admin` | the operator UI, the admin API, the credential-ENTRY workflow | the ONLY published port |
| `vault` | provider secret storage and brokering | none; pod-internal |

**One published port, two containers.** Port count and container count are
independent. `config-admin` is published; `vault` is reachable only on the pod
network. The published port was never the boundary.

## Why not merge them

- **The UI is the attack surface; the vault is the asset.** `config-admin`
  parses untrusted browser input and serves JS. A vault earns its keep by
  having a tiny surface. Merged, every UI bug is a vault bug.
- **Churn is opposite.** A UI changes constantly; a vault should change almost
  never. A shared deployment unit makes UI churn force vault redeploys, and
  every vault redeploy is a moment of credential risk.
- **Fault coupling runs the wrong way.** A UI crash would take the vault with
  it and cost `llm-plane` its credential source -- an admin-surface fault
  reaching the inference path, which is what splitting `config-admin` out of
  `switch` was meant to prevent.
- **An allowlist is meaningless in-process.** 2026-08-30d required `vault` to
  enforce an explicit caller allowlist. In one process there is no caller to
  allow or deny.

## The condition that makes this real

A two-container split buys nothing if the hop between them is unauthenticated.
An open HTTP call across the pod network is not safer than a function call and
is arguably worse, because the secret now crosses a network we have not
defended. **Therefore the authenticated, allowlisted `vault` API is part of
this decision, not a follow-up.**

- Every `vault` call carries a caller credential. No anonymous access.
- The caller credential has **no default value**. A container that is not given
  one fails closed at boot. (`SECRET_KEY_BASE` defaulting to
  `"mind-pod-not-a-secret"` in this repo is the anti-pattern; do not repeat it.)
- The allowlist is by caller identity AND operation, not caller identity alone.

## Read-back asymmetry

`config-admin` may **write** a secret and may **never read one back**. Secret
values are returned only to `llm-plane`, and only for an allowlisted operation.
The UI shows presence, source metadata, and test results -- never a value.

This is the property that makes the split worth its cost: compromising the only
host-published surface yields the ability to *replace* a credential, not to
*exfiltrate* one.

## Constraints inherited from the operator and from 2026-08-30c/d/g

- Keys are placed by a human through a UI. No agent writes key material.
- Keys must survive `docker compose down -v`. They live behind a bind mount
  today for exactly this reason; a named volume is not acceptable.
- **No migration step may leave the pod unable to accept a key.** The new entry
  path and durable storage must both work before the old path is removed.
- `vault` holds no domain state, participates in no events, and shares no
  writable volume with `back`, `backjob`, `mind`, `llm-plane`, or `persist`.
- Secret values never appear in logs, events, telemetry, or durable state.

## Status of the rest of the re-partition

This ADR authorizes the `switch` decomposition ONLY. `persist`,
`graph-projector`/`graph-store`, `effect-plane`, and `blob-store` remain
unauthorized. The `backjob` storage isolation recommended as the first cutover
in 2026-08-30g is a separate decision and is not taken here.

## Naming

The upstream stays `nvidia-nemo-switchyard`. The bare name `switchyard` is
retired from our own components -- it currently names two different things and
has already produced one architectural error.

## Amended by ADR 0047 (same day)

This ADR originally said, per 2026-08-30g Q3, that the Node service is
`llm-plane`, and it assumed `config-admin` would be split OUT of the Node
process. ADR 0047 assigns Rust to SWITCH and Ruby-in-Rails-form to everything
else, so:

- `config-admin` is a **Rails** application in its own container. It is BUILT,
  not split out of Node.
- `vault` is a **Rails** application in its own container.
- SWITCH becomes Rust, pending the open question in 0047 about what SWITCH is.

Every condition above stands unchanged: authenticated allowlisted API, no
default caller token, fail-closed boot, read-back asymmetry, one published
port. Only the implementation language and the build-versus-split framing move.

## Amendment 2: the inbound edge is a CPCP contract (TBD)

Vault's inbound edge becomes a **CPCP contract**. The shape of that contract is
not yet decided.

Today it is bespoke REST, landed at `968d3cd`: `GET /secrets`, `POST /secrets`,
`GET /secrets/:name`, bearer token, allowlist keyed on `(token -> identity ->
operation)`. That surface is what changes.

**Five seams now.** BACK, MIND (0048), SwitchYard (0050), `bus` (0050), and
vault. Gap 20 -- authority stated for one of them -- grows by one.

### What must survive the translation

Every condition of this ADR is unchanged by the transport. In particular:

- **Read-back asymmetry.** Today it is enforced by operation name in
  `Vault::Api`: `get` is refused to `config-admin` before the store is touched.
  Under CPCP the allowlist keys on the **method**, and the refusal must stay
  ahead of the store, not become a response filter.
- **No default caller token; fail-closed at boot.**
- **Pod-internal only.** A CPCP seam does not make vault publishable.

### The tension to resolve, not paper over

CPCP's envelope **never raises**: `{ok: false, reason:, because:}`. Vault today
answers **401** and **403** at the HTTP layer.

A credential broker that answers `200` to a refused read is harder to monitor,
easier to mishandle in a client that checks status codes, and loses the signal
that perimeter tooling watches for. Whether vault's refusals stay HTTP-coded
inside a CPCP envelope, or collapse into `ok:false`, is a real decision and
should be made explicitly.

### Sequencing: this must land BEFORE config-admin

`config-admin` is next on the critical path and is vault's **first caller**.
Built today it would target the REST surface; built after, the CPCP contract.

Building it first means writing the caller twice and throwing one away.
**Define the contract before `config-admin`, or accept the rework knowingly.**

### Contract definition follows the shape thread

Per the correction in ADR 0048, CPCP's language-neutral data contract is SHACL.
Vault's contract is therefore **shapes**, which places vault on the same thread
as `ROLE=shape` and gives it the same distribution question.
