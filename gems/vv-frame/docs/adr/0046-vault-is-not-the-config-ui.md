---
type: Architecture Decision
title: "VAULT is a separate container from CONFIG-ADMIN; the published port is not the boundary"
adr_id: "0046"
status: accepted
date: "2026-08-30"
description: "Three containers out of today's one, and vault is not config-admin."
okf_version: "0.2"
tags: [runtimes, extract, rung-3, gold, refusal, switch, vault, config-admin, llm-plane]
resource: "magentic-stack/docs/adr/0046-vault-is-not-the-config-ui.md"
sources:
  - magentic-stack/docs/adr/0046-vault-is-not-the-config-ui.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - runtimes/switch
  - runtimes/mind-pod/docker-compose.yml
enforced_by:
  - runtimes/mind-pod/docker-compose.yml
  - tooling/compose/check_role_routes.py
  - tooling/cpcp/check_vault_cpcp.py
  - tooling/cpcp/check_config_vault_client.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0046 — VAULT is a separate container from CONFIG-ADMIN; the published port is not the boundary

## Decision

**Three containers out of today's one, and `vault` is not `config-admin`.** | Target | Owns | Host exposure | |---|---|---| | `llm-plane` | routing, provider adaptation, translation, data-plane health (today's 8789) | none; pod-internal | | `config-admin` | the operator UI, the admin API, the credential-ENTRY workflow | the ONLY published port | | `vault` | provider secret storage and brokering | none; pod-internal | **One published port, two containers.** Port count and container count are independent. `config-admin` is published; `vault` is reachable only on the pod network. The published port was never the boundary.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — Separating the credential holder from the admin surface refuses a second home for secrets.
* [Layers](../frame.md#layers) — The published port is not the boundary — exposure and ownership are different questions.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `runtimes/mind-pod/docker-compose.yml`
* `tooling/compose/check_role_routes.py`
* `tooling/cpcp/check_vault_cpcp.py`
* `tooling/cpcp/check_config_vault_client.py`

## Source

* Full record: `magentic-stack/docs/adr/0046-vault-is-not-the-config-ui.md`
* Frame: [One Frame](../frame.md)
