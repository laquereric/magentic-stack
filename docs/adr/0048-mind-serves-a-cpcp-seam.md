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

---

# Correction: the shape thread IS the language-neutral definition

This ADR said CPCP "has no language-neutral specification" and that "the contract
IS the Ruby implementation". **That is wrong**, and the correction was written in
the code I was reading past. `grounding.rb:123`:

> These reproduce the SHACL constraints in Ruby because the TTL is NOT executed
> in-process [...] **The shapes are the specification** and CI runs pyshacl over
> them with fixtures; THIS is what actually refuses a live request, so the two
> must say the same thing.

So the arrangement is the opposite of what I described. The **shapes are
normative**; the Ruby is a deliberate hand-written reproduction, because
`mm-shacl-reader` is not wired in-process; and `gate-shacl-conformance` runs
`pyshacl` over the TTL plus a drift checker to keep the two in step.

## What this changes

### The prerequisite is distribution, not authorship

A Python or Rust seam does not need a specification written for it. It needs the
**TTL at runtime**. That is exactly what `shapes-level-8` and
`shapes-application` package and what `ROLE=shape` (ADR 0049) would serve.

**`ROLE=shape` therefore moves onto the critical path.** ADR 0049 called it an
interim surface before `app-shacl-store`; it is better described as the
mechanism by which any non-Ruby implementation obtains the protocol definition.
It is a prerequisite for MIND's seam, not a nicety alongside it.

### A Python seam would be MORE faithful than BACK, not less

`pyshacl==0.40.1` is already pinned in `tooling/shacl/requirements.txt`. A Python
CPCP seam can execute the shapes directly. BACK cannot -- it reproduces them by
hand, with an explicit allow-list that the module comment calls out as "explicit,
not generated".

The divergence risk therefore runs the other way from what this ADR assumed: the
odd implementation out is the Ruby one, and there is already a gate on it.

### What the shapes still do NOT define

SHACL constrains **structure**. It does not carry:

- the never-raise envelope (`{ok:, reason:, because:}`)
- `operationId`, idempotency scope, replay semantics, receipt/outcome cids
- the method registry -- which methods exist at all
- error taxonomy, ordering, versioning

That half is still Ruby-only, and it is why `grammar/osi-level-8` exists as
normative prose and is frozen rather than deleted. **The data contract is
language-neutral; the behavioural contract is not.** A second implementation can
validate payloads today and would still have to infer behaviour from Ruby.

### Two gaps get sharper

- **`osi.example` (gap 22)** is no longer a stored defect. If the shapes are the
  specification, an unresolvable placeholder is in the **specification's own
  identifiers**.
- **Migration (gap 23)**: 7 TTL are packaged in the shape gems, 52 remain in
  `osi-level-8-profiles`. The specification is roughly one-eighth distributed.
