---
id: "0068"
title: Internet A2A is the host/external binding; loopback BACK 404s the well-known Card
status: accepted
date: 2026-09-09
subject_kind: protocol
subject: a2a
components: [a2a, back, rails-cpcp]
paths:
  - gems/rails-cpcp/lib/rails_cpcp/a2a_internet.rb
  - runtimes/mind-pod/app/app/controllers/a2a_internet_controller.rb
  - runtimes/mind-pod/app/config/routes.rb
enforced_by:
  - gems/rails-cpcp/spec/a2a_internet_spec.rb
  - tooling/compose/check_a2a.py
  - tooling/compose/plant_a2a.py
supersedes: null
superseded_by: null
---

# Internet A2A is the host binding

## Decision

1. **The internet A2A binding is host-published HTTP.** Discovery is
   `GET /.well-known/agent-card.json`. The JSON-RPC frame is `POST /_a2a/rpc`.
   `preferredTransport` is `HTTP`. Payloads are the same JSON-LD Context /
   Effect DataParts as intrapod (ADR 0067). This is not a thirteenth
   container and not an in-pod path (ADR 0066).
2. **Loopback does not speak internet A2A.** `HTTP_BIND=127.0.0.1` (in-pod
   BACK) 404s the well-known Card and `/_a2a/rpc`. `HTTP_BIND=0.0.0.0`
   (extract BACK, CI host-published BACK) serves them. Host-published HTTP
   is a different surface, not a backup path for in-pod calls.
3. **The internet Card must not advertise `nats://nats:4222` or
   `http://back:3000`.** Those are in-pod addresses. NATS discovery remains
   `agent/card` on `a2a.<agent>.rpc`.
4. **`POST /_cpcp/rpc` stays CPCP JSON-RPC-LD.** Mixing A2A `message/send`
   onto that path would break existing CPCP clients. A2A HTTP is `/_a2a/rpc`.

## Why 404 on loopback

In-pod HTTP is bound to loopback so sibling containers cannot dial it
(ADR 0065 amendment 2). Serving a well-known Agent Card there would still
be an HTTP A2A path inside the pod, which intrapod conformance forbids.
Extract BACK is the operator/internet surface; that is who speaks this
binding.

## Consequences

- ROLE=back draws the two routes. Other roles do not.
- Clients MUST inspect HTTP status and the JSON-RPC/CPCP envelope
  (dual-signal, `spec/http-mapping.md`). Well-known is 200 + Card or 404.
- Intrapod NATS A2A carries `Authorization` as a NATS header, never a
  JSON-RPC param, matching the vault contract.
