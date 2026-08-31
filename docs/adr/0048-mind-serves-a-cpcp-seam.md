---
id: "0048"
title: MIND serves its own CPCP seam and owns the NOOA push/pull mapping
status: accepted
date: 2026-08-31
subject_kind: topology
subject: MIND
components: [mind, rails-cpcp, back]
paths:
  - runtimes/mind-pod/mind
  - gems/rails-cpcp
enforced_by: []
supersedes: null
superseded_by: null
---

# MIND serves a CPCP seam

## Decision

The Python MIND image **provides a `/_cpcp/rpc` endpoint**, and holds all the
logic needed to map **NOOA push and pull**.

## What this inverts

Today MIND is a pure CPCP **client**. `harness.py` PULLs context and PUSHes an
effect proposal, both against `BACK_URL + /_cpcp/rpc`, using stdlib `urllib`.
The container has **no HTTP server, no `EXPOSE`, and no inbound surface at all**
-- `CMD ["harness.py"]`.

`mind_agent.py:58` currently says, of MIND:

> There is no second socket, and there is no write path for you at [MIND]

That sentence is **false as of this ADR** and must be rewritten rather than
left to rot. It is load-bearing prose: it is the doctrine a reader learns MIND
from.

"Push" and "pull" also change meaning. Today they name what MIND does TO BACK.
Under this ADR MIND also EXPOSES a seam that maps NOOA's push and pull.

## The gap that blocks implementation

**CPCP has no language-neutral specification in this repository.**

`gems/rails-cpcp` is a Rails engine -- `app/controllers`, `lib`, `config`,
`deploy`, `front`, and an rspec suite. There is no schema, no protocol
document, and no conformance suite. **The contract is the Ruby implementation.**

So a Python `/_cpcp/rpc` would be a second implementation of an unspecified
protocol. The two seams would agree only for as long as someone kept reading
both. That is the same failure mode as ADR 0047 amendment 2 -- a boundary held
by convention rather than by construction -- and it fails the same way: quietly,
and only under load.

**Prerequisite: a written CPCP contract plus a conformance suite that BOTH the
Rails seam and the Python seam must pass.** The Ruby implementation is the
source to extract it from; it is not itself the specification.

(Related: `laquereric/json-rpc-ld` is the spec-only repo, and CPCP is described
as a conforming profile of JSON-RPC-LD. Whether that spec is complete enough to
implement against is not established and should be checked before writing a
line of Python.)

## Two seams, and what each is authoritative for

The pod will have **two `/_cpcp/rpc` endpoints**. Every existing statement of
the invariant -- in `routes.rb`, in the compose header, in `mind_agent.py` --
was written when there was one, and says the seam is *the only write path*.

That is now ambiguous, and the ambiguity is the same class of defect as
`backjob`'s direct `Reconciliation.create!`: an unstated second writer.

| Seam | Authoritative for | Status |
|---|---|---|
| BACK `/_cpcp/rpc` | domain state; the sole domain writer | established |
| MIND `/_cpcp/rpc` | the NOOA mapping | **must be stated**: adapter surface, or a second authority? |

Until that row is filled in, "BACK is the sole writer" cannot be read literally
and should not be quoted as though it were.

## Constraints on the implementation

- **Pod-internal only.** MIND gains an inbound surface for the first time. It
  gets no published port. Who may call it is an allowlist decision of the same
  kind ADR 0046 made for `vault`, and it should be made deliberately rather
  than defaulting to "anything on the pod network".
- **Stdlib, not a web framework.** `requirements.txt` records that the harness
  uses "only the Python stdlib (urllib/json/hashlib) + NOOA". A seam serving one
  method shape does not justify FastAPI plus uvicorn, their transitive
  dependencies, the image growth, or the CVE surface. `http.server` is the
  coherent choice under ADR 0047's cognitive-load principle.
- **MIND still holds no provider credential and names no model.** Cognition
  still goes to SWITCH. Serving a seam does not change that.
- **The route-gating invariant of ADR 0047 amendment 2 does not reach MIND.**
  That mechanism is Rails `routes.rb`. MIND needs its own equivalent: its seam
  exposes the NOOA mapping and nothing else, proven by a plant.
