# OSI Level 8 — Profile 2: Reference-Passing for Agents (NOOA)

**Review-ready draft.** A profile of *OSI Level 8 — Base* [BASE]. Formalizes the design memo *Portable References and Typed Effects for a NOOA–Level-8 Cyborg Channel* [MEMO].

## 1. Abstract

Profile 2 is the agent-facing conforming profile for the OSI Level 8 base [BASE]. It is designed for a Cyborg whose compute machinery includes a Large Language Model operating under a NOOA-style harness [NOOA] — a harness whose signature move is *pass-by-reference*: a large result stays alive in the runtime and the model receives a typed, bounded preview rather than the full payload. Profile 2's thesis: **a JSON-RPC-LD `@id` (an IRI) is a pass-by-reference handle that is portable across process and trust boundaries.** From that single identification: BACK publishes a typed method surface; the model reads Context BY REFERENCE (bounded previews dereferenced on demand); and the model returns structured output as a typed Effect that is enforced identically at decode time and at ingest time.

## 2. Relationship to the Base and related specifications

This document is a PROFILE of the base [BASE], section 9. It uses the base protocol [JSON-RPC-LD] — grounding (`@id`/`@type`/`@context`), the never-raise envelope, and `operationId` idempotency — and the base's closed SHACL contracts [SHACL]. It realizes three NOOA capabilities [NOOA] over the wire: pass-by-reference, typed input/output, and model-callable harness APIs. It MUST NOT weaken any base requirement. Where Profile 1 [PROFILE-1] grounds data as typed rows, Profile 2 governs how an agent *reads and acts on* that data across the Level-8 boundary; a deployment MAY layer Profile 2's method surface over Profile-1-grounded records.

**Scope (deliberately minimal).** Profile 2 uses only a subset of the base. It does NOT use the `private_local` ledger — Profile 2 exposes no private data — and it does NOT use `baseVersion` optimistic concurrency — Effects are idempotent, keyed by `operationId`. Both remain defined in the base [BASE] for deployments that need them; the design memo [MEMO] explores the fuller variant.

## 3. Portable references

An `@id` is an IRI: a global, stable name for a resource. Unlike an in-process object handle (a Python reference, valid only inside one runtime), an IRI is serializable and therefore portable across processes and across trust boundaries. Profile 2 treats the `@id` as the pass-by-reference handle the model holds.

- The analogy HOLDS for identity and for dereference-on-demand: the model can name a resource, pass the name around, and fetch it later.
- The analogy BREAKS where in-process handles are total: an IRI's **lifecycle** is owned by BACK, not by the holder, and **dereference is authorized**, not guaranteed. A conforming implementation MUST treat every dereference as a fresh, authorized read.

## 4. API-surface publication

BACK MUST publish a typed **method surface** the model may call: a manifest of methods, each with its JSON-LD shape for `params` and `result` expressed as a closed SHACL shape [SHACL]. This is consistent with the base rule that JSON-RPC-LD defines no specific shapes — the profile and BACK supply them. The manifest is itself grounded (each method and shape has an `@id`). A negotiate step MAY pin the manifest version the session uses. The published surface is exactly the set of Context reads and Effects the model is permitted to attempt; anything not on the surface is refused by default (default-deny).

## 5. Reading Context by reference

- `canonical.pull` returns bounded **previews** plus IRIs, not full payloads. A preview MUST contain: the resource `@id`, its `@type`, and a bounded, typed digest sufficient for the model to decide whether to dereference. A preview MUST NOT carry unbounded free text.
- The full record is fetched only ON DEMAND via `canonical.get` by `@id`, and only for IRIs on the published surface. Because the transcript accumulates previews and references rather than payloads, the context window does not flood and the prompt prefix stays stable — the NOOA token and prompt-cache benefit, obtained over the wire.

## 6. Structured output as a typed Effect

The model's schema-constrained decoding output IS a JSON-LD Effect record. The closed SHACL shape BACK published for the method is EXACTLY that output schema, so the SAME typed surface is enforced TWICE:

- at **decode time**, as the grammar / structured-output constraint the model generates under, and
- at **ingest time**, as the closed SHACL shape validated on the pushed Effect.

The two MUST be derived from one source of truth (one shape compiled to both a decoding grammar and a SHACL file) so they cannot drift. The Effect carries an `operationId` (idempotent, apply-at-most-once). On acceptance BACK applies the Effect to CANONICAL and returns a signed receipt; on rejection it returns `{ ok: false, reason:, because: }`. A server-authoritative field appearing in an Effect is a shape violation and MUST be refused before it can touch canonical state.

## 7. Trust and isolation boundary

The harness that runs the model is a client of BACK; BACK remains the sole writer and the reference monitor. NOOA's own caveat carries over verbatim: the harness's static checks (AST validation, deny-lists) are defense-in-depth, NOT a containment boundary [NOOA]. The containment boundary is the isolation layer around the harness (container / microVM / restricted fs, network, credentials) together with the Level-8 default-deny surface. Because the model holds only references and BACK re-authorizes every dereference and every Effect, a compromised or prompt-injected model cannot exceed the published surface.

## 8. Conformance

A conforming Profile 2 deployment MUST: publish a grounded, closed-shape method surface; return previews (never full payloads) from `canonical.pull`; authorize every `canonical.get`; derive the decode-time schema and the ingest-time SHACL shape from one source; enforce `operationId` idempotency on every Effect; and refuse any Effect carrying a server-authoritative field.

## 9. References

- [BASE] OSI Level 8 — Base — A Cybernetic Interface. https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-base.md
- [PROFILE-1] OSI Level 8 — Profile 1: The Cyborg Channel. https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-profile-1-cyborg.md
- [MEMO] Portable References and Typed Effects for a NOOA–Level-8 Cyborg Channel. https://github.com/laquereric/vv-nooa/blob/main/docs/research/nooa-level-8-design-memo.md
- [JSON-RPC-LD] JSON-RPC-LD: A Linked Data Extension for JSON-RPC 2.0. https://github.com/laquereric/json-rpc-ld
- [NOOA] NVIDIA Object-Oriented Agents (labs-OO-Agents). https://github.com/NVIDIA-NeMo/labs-OO-Agents
- [SHACL] Shapes Constraint Language (SHACL), W3C Recommendation. https://www.w3.org/TR/shacl/
- [TODO-PY] todo-app-python — Cyborg Channel FRONT/BACK reference implementation. https://github.com/laquereric/todo-app-python
