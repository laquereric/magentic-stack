---
id: "0065"
title: NATS is the 12th container, the in-pod L7 broker; BUS remains the metadata seam
status: accepted
date: 2026-09-08
subject_kind: topology
subject: nats
components: [nats, bus, back, vault, persist, mind, switch]
paths:
  - runtimes/mind-pod/docker-compose.yml
  - runtimes/mind-pod/app/extract/compose.yml
  - tooling/compose/check_nats.py
  - tooling/compose/language_rule.json
  - gems/rails-cpcp/lib/rails_cpcp/nats_binding.rb
enforced_by:
  - tooling/compose/check_nats.py
  - tooling/compose/plant_nats.py
  - tooling/compose/check_language_rule.py
  - gems/rails-cpcp/spec/nats_binding_spec.rb
  - tooling/compose/check_nats_exclusive.py
  - tooling/compose/plant_nats_exclusive.py
  - tooling/compose/check_http_bind.py
  - tooling/compose/plant_http_bind.py
supersedes: null
superseded_by: null
---

# NATS is the in-pod L7 broker

## Decision

1. **`nats` is a twelfth running container** in mind-pod. It is the official
   `nats-server` image, digest-pinned, unpublished, with JetStream on a named
   volume `nats-data`. It is the same *class* of thing as `graph` (oxigraph):
   third-party, unforked, we ship no source into it.
2. **It is not `ROLE=bus`.** BUS remains the Rails CPCP seam plus an async
   sqlite projection of metadata derived from BACK's journal (ADR 0050
   amendment 2, row 18). NATS is Level 7 transport. BUS may later *publish*
   as a NATS client; it must never *be* the broker.
3. **In-pod CPCP rides NATS.** JSON-RPC-LD envelopes travel on
   `cpcp.<role>.rpc` request-reply. The payload is the same PDU HTTP carries;
   NATS headers carry `Authorization`. OSI L8 §10.2: HTTP and NATS MUST
   preserve identical Level 8 semantics. JetStream sequence numbers MUST NOT
   replace `operationId`.
4. **HTTP inside the pod can be disabled.** Host-published HTTP
   (`config :13003`, extract FRONT `:13000`, extract BACK `:13002`) remains
   the operator/internet surface. In-pod `expose: 3000` on CPCP roles is no
   longer load-bearing once clients use NATS. SPARQL (`graph :7878`) and the
   LLM data plane (`switch :8789`) stay HTTP — they are not CPCP.
5. **`project-graph` stays embedded in BACK.** Row 7's reserved "12th
   container" slot is spent here. Projection is already wired and measured
   inside BACK; splitting it out is not what this slot was spent on.

## Why this and not folding into BUS

A Go broker and a Rails projector need a boundary (ADR 0047 §2). Mixing them
would invert row 72 (a CPCP call must complete with BUS the *projection*
down) and recreate the second-event-log trap that declined RES (row 17).
JetStream is transport durability, a fourth kind of state beside ADR 0057's
three. Crash, image, and port are independent of `bus.sqlite3`.

## Images

Five images, still three languages we write:

| Image | Containers |
|---|---|
| Rails (`mind-pod`) | back, backjob, front, vault, config, shape, bus, persist |
| MIND | mind |
| Switch | switch |
| oxigraph (third-party) | graph |
| nats (third-party) | nats |

LOG (ADR 0058) remains decided-unbuilt. Its job is unchanged; the integer
in "thirteenth container" was a count, not the substance.

## Consequences

- `MM_NATS_URL=nats://nats:4222` on every in-pod CPCP participant. Empty
  means HTTP-only (tests, host curl). Compose always sets it.
- Language-rule exemption for `nats` meets the same four conditions as
  `graph`. A new container must meet them, not inherit the name.
- `nats` is never in `ports:`. Publishing `:4222` is a failed sweep.
- BACK's journal remains the only admission truth (ADR 0052). NATS is not
  a log of operations.
- Dual-bind is the landing: NATS is preferred when `MM_NATS_URL` is set;
  HTTP remains so host CPCP and existing tests keep working. Removing
  in-pod `expose: 3000` is a follow-up once the NATS path is the one that
  is measured, not the one that is hoped.

---

# Amendment, same day: HTTP is not a fallback

The dual-bind sentence above is **withdrawn** as a runtime rule. It
described a landing sequence; it must not be read as "NATS fails, so
call HTTP."

**Now:**

- `MM_NATS_URL` empty → HTTP (tests, host curl against extract BACK).
- `MM_NATS_URL` set → NATS only. A silent broker, a missing `nats-pure`,
  or a timeout is `nats_unreachable`. HTTP is not a fallback.

Host-published HTTP (`config :13003`, extract FRONT `:13000`, extract
BACK `:13002`) is a different surface, not a backup path for in-pod
calls. SPARQL and the LLM data plane stay HTTP because they are not
CPCP.

---

# Amendment 2, same day: in-pod HTTP binds loopback

A process listening on `0.0.0.0:3000` is still reachable on the docker
network even when `expose` is omitted. In-pod CPCP roles therefore bind
HTTP to `127.0.0.1`. Only host-published operator surfaces opt into
`HTTP_BIND=0.0.0.0`. The entrypoint default is loopback.

Gated by `check_http_bind.py`.

