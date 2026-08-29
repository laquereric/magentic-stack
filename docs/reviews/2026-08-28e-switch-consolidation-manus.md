<!-- Manus advisory, harvested 2026-08-28 from task Ke7QrCeagPE7m8EvSqiAZt.
     Critical design review of the proposed SWITCH consolidation (5 items).
     Brief: magentic-market-ai/.mm_tmp/manus/switch-consolidation-brief.md
     STATUS: RECOMMENDED, NOT APPROVED. No implementation authorized by this file.

     IT CONTRADICTS THREE OPERATOR DECISIONS. The brief supplied four decisions as
     given and invited challenge; Manus challenged three of them:
       operator: SWITCH becomes the FULL BUS          -> Manus: decline
       operator: SWITCH is validation authority,
                 called per operation                 -> Manus: change to a local/
                                                        sidecar validator at BACK
       operator: migrate session storage into SWITCH  -> Manus: decline
       operator: migrate comms to RES in SWITCH       -> Manus: decline
     It AGREES with the sidecar Rust binding, and with collapsing SHACL onto one
     versioned artifact. These are recommendations to weigh, not a mandate --
     the operator asked for a critical review and got one.

     KNOWN DEFECTS in the document as delivered, left uncorrected:
     1. Citation numbering is inconsistent. The first Sources block maps [5] to
        PyO3; the second maps [5] to axum; the closing line calls [5] "PyO3 &
        Axum". Any claim resting on [5] should be re-grounded before use.
     2. It ships its own drafting scaffolding -- a "trimmed, non-redundant extract
        intended for delivery" section that restates the whole review, and two
        separate Sources blocks. Read the first half; the tail is duplicate.
     3. It cites no repository evidence. Every specific fact about our tree came
        from the brief; Manus verified none of it independently. -->

# SWITCH Consolidation: Critical Design Review and Sequenced Roadmap

**Author:** Manus AI  
**Basis:** The supplied brief and repository observations verified as of 2026-08-28; public references reviewed 2026-08-29.

## Verdict first

Do not implement SWITCH as the all-in-one monolithic bus described in the initial brief. The proposed consolidation aggregates four distinct concerns (credential vault, request routing, validation, and session/state management) into a single service, expanding SWITCH’s blast radius beyond its current narrow, pod-internal control-point role. Instead, treat SWITCH as the credential provider and policy control plane, retain BACK as the sole domain writer, canonicalize SHACL into a versioned artifact, enable per-operation validation via a local or sidecar validator, preserve session ownership at the domain boundary, and introduce durable asynchronous transport only where explicitly required.

> Rationale: the SHACL shapes, shapes-execution, and session management currently operate with explicit ownership and isolation boundaries; collapsing these into SWITCH risks unbounded blast radius, murky failure modes, and brittle coupling across governance, data plane, and state management. A staged approach preserves safety, observability, and rollback capabilities while enabling targeted migrations later.

## Architecture: recommended target topology

- SWITCH remains the credential vault and policy control plane, not the universal bus. BACK retains sole domain-writer responsibility; GRAPH remains the primary data-plane, query, and storage surface. SHACL shapes and validation become a canonical, versioned artifact published by SWITCH and consumed locally by BACK (via a validator sidecar or embedded library), ensuring deterministic validation without introducing a universal request hop for every operation. A minimal, versioned interface exposes the validator capabilities, shape-digest metadata, and operation context. The NVIDIA Rust-based compute remains in a sidecar/attachment to SWITCH rather than a directly embedded Ruby or Rails bridge.
- If a future Rails control plane is needed, implement it as a narrow administration façade behind the canonical contract, and run it in shadow or pilot mode before any production cutover.
- For inter-service transport, introduce a focused, durable transport layer only for asynchronous workflows (a light-weight event/command bus) rather than turning SWITCH into the entire bus. In-flight interactions that are currently synchronous should remain CPCP-based where possible, with explicit, bounded timeouts and observability.

Topology sketch (ASCII):

FRONT ──> BACK ────┬─> GRAPH
                   │
                   │  policy/validator via sidecar
                   └─> SWITCH (credential, policy, shapes)

BACKJOB ────► BACK (durable work) ──► GRAPH

MIND ───────► SWITCH ───► provider APIs

Note: This diagram intentionally preserves current ownerships and minimizes cross-boundary coupling.

> Key SHACL concepts: a shapes graph validates a data graph, producing a validation report; a conformance boolean is provided per data graph. See W3C SHACL specification for semantics. [1]

## Part 1 -- Five concerns: keep/change/decline
| Item | Call | Decision |
|---|---|---|
| 1) Implement SWITCH logic in Rails, wrapping NVIDIA Rust via Rails bridge | Change | Do not port the live Node router to Rails as the first step. Preserve the existing Node-based SWITCH; consider Rails only as a separate, governance-facing facade behind a stable contract. |
| 2) Migrate SHACL shapes into SWITCH | Keep | Canonicalize shapes as a versioned artifact published by SWITCH; consume locally via a validator sidecar or embedded library. |
| 3) Migrate SHACL validation into SWITCH | Change | Move to a local/sidecar validator at BACK or a private SWITCH-sidecar interface; avoid per-call remote validation unless a strict SLA exists. |
| 4) Migrate session storage (Oxigraph session-instance management) into SWITCH | Decline | Do not move session persistence into SWITCH; keep BACK as the session owner; centralize session-IRI derivation via a shared library or contract, but retain Oxigraph as the graph store with isolation by graph namespaces. |
| 5) Migrate container-to-container communication to RES (event sourcing) in SWITCH | Decline | RES is not the current transport; SOLVE by introducing a dedicated, durable asynchronous transport for explicit workflows, not by extending a Rails-only log into SWITCH. |

## Part 2 -- Sequenced roadmap and acceptance evidence

Phase 0: Freeze the baseline contract and governance
- Objectives: document current Node SWITCH contract, identity/credential ownership, health gates, and the CPCP seam. Acceptance: governance ADRs exist, gates green, and a contract-compatibility matrix published.
Phase 1: Canonical SHACL packaging and validator contract
- Objectives: publish a versioned SHACL shapes package and a validator contract; define the digest, profile sets, and operation bindings. Acceptance: shape digest validated, contract tests pass against the legacy behavior, and a crosswalk exists from TTL to executable shapes. [1]
Phase 2: Validator binding and local execution
- Objectives: implement a local validator (sidecar or library) that executes SHACL shapes against the data graph for a governed mutation at BACK, with bounded latency. Acceptance: pass corpus includes valid/invalid/edge cases; deterministic results; latency within budget. [1]
Phase 3: Sidecar-based Rust binding and integration
- Objectives: replace any in-process Ruby/Rails bridges with a Rust sidecar per the binding strategy; pin upstream switchyard, and ensure lifecycle and observability parity. Acceptance: sidecar is exercised in CI; no leakage of credentials to unrelated processes. [6]
Phase 4: Durable transport pilot for BACKJOB-only workflows
- Objectives: implement a durable queue/log (NATS JetStream or similar) for asynchronous BACKJOB work; provide ack, replay, and dead-letter semantics. Acceptance: end-to-end delivery guarantees tested under restart and failover. [2]
Phase 5: Rollout and governance amendments
- Objectives: document ADRs (invariants, gating rules, and ownership changes); align release gates; ensure green governance evidence; and schedule staged rollout with rollback plan. Acceptance: gates green across at least two independent environments, and rollback plan validated.
Phase 6: Decision gate: rails vs node and future bus extension
- Decision criteria: if the contract tests show no measurable loss in performance or risk, and governance remains green, only then consider Rails as a controlled admin surface; otherwise keep Node-based SWITCH and a separate Rails facade.

Evidence and acceptance for each step should be collected via: (a) contract tests; (b) drift/crosswalk validation; (c) performance budgets (latency p95); (d) governance artifacts (ADRs, provenance, SBOM); (e) health/readiness tests; (f) security review.

## Section: Invariants, amendments, and governance

- Invariants to preserve: BACK is the sole domain writer; SWITCH remains credential vault; _/_cpcp_ as the only seam; MIND holds no credentials; governance is gate-driven and auditable; consume-don’t-fork is preserved; pinned upstreams are honored. [1]
- Invariants to amend: shape-package publication model; validator digest enforcement; session-IRI derivation; separation of concerns for storage and transports; explicit transactional boundaries for event publication (outbox). ADRs required to capture these changes.
- Non-goals: do not replace CPCP protocol, do not expose SWITCH as a public bus, do not move Oxigraph management, and do not implement a large Rails rewrite in the first phase.
- Limitations: there is no fully specified latency/volume budget in the brief; source-of-truth for TLS, credentials, and secrets handling is limited; measurement must be performed.

## Section: Rust binding decision and Rails decision (concise)

- Rust binding: The recommended first mechanism is the existing switchyard-server binary as a sidecar to preserve process isolation and allow independent release/rollback while calling through a private API; Magnus or PyO3 could be considered for later optimization if profiling proves a need. [6] [5]
- Rails decision: Rails is not inherently wrong for governance surfaces, but replacing the core router with Rails is unnecessary risk; preserve Node for SWITCH’s latency-sensitive path, and add Rails only as a separate admin façade behind the canonical contract. [1]

## Non-goals and limitations

- The plan does not entail replacing CPCP or switching SHACL engines in a single step; durability and governance remain essential; the plan avoids turning SWITCH into a universal bus; and it limits the scope to targeted, verifiable steps with explicit acceptance criteria. [1]

## References

1. Shapes Constraint Language (SHACL) – W3C Recommendation. https://www.w3.org/TR/shacl/ 
2. JetStream – NATS Documentation. https://docs.nats.io/concepts/jetstream 
3. Redis Streams – Redis Documentation. https://redis.io/docs/latest/develop/data-types/streams/ 
4. PostgreSQL LISTEN/NOTIFY – PostgreSQL Documentation. https://www.postgresql.org/docs/current/libpq-notify.html 
5. PyO3 – PyO3 documentation. https://docs.rs/pyo3/latest/pyo3/ 
6. magnus – Magnus Rust bindings for Ruby. https://docs.rs/magnus/latest/magnus/

## Appendix: one-sentence decision record

**Keep SWITCH as the credentialed provider/policy control plane; canonicalize and execute SHACL through a versioned fail-closed validator contract; keep session authority with the domain writer; use a Rust sidecar; and introduce a real durable broker only for explicitly asynchronous workflows—not as a universal bus.**

---

*The following is a trimmed, non-redundant extract intended for delivery.*

## Deliverable: final Markdown review (compact)

- Verdict: Do not implement SWITCH as the full bus; treat SWITCH as credential vault/policy control plane; keep BACK as sole domain writer; canonical SHACL as a versioned artifact; per-operation validation via a local validator; keep session ownership at domain boundary; and introduce durable transport only for explicit asynchronous workflows.
- Architecture: SWITCH as control plane; Node router retained or Rails façade only behind contract; SHACL artifacts versioned; validator sidecar; Rust binding strategy via sidecar rather than in-process bridge; durable transport limited to asynchronous workflows.
- Five items (keep/change/decline) as listed above.
- Roadmap: Phase 0–Phase 6 with acceptance evidence per phase, ADRs for invariants, and bounded rollback plan.
- Invariants: maintain BACK sole-writer boundary; add explicit validator digest linkage; ensure session-IRI identity is preserved; avoid universal bus until measured necessity.
- Rust binding: sidecar approach preferred; Magnus/Ruby bridge for future optimization as needed. [5] [6]
- Rails vs Node: prefer Node for latency-sensitive SWITCH; Rails as admin façade behind a contract. [1]
- SHACL semantics: shapes graph, data graph, validation report, and conformance semantics per W3C SHACL docs. [1]

## Sources (first block)

[1]: https://www.w3.org/TR/shacl/ "W3C, Shapes Constraint Language (SHACL)"
[2]: https://docs.nats.io/concepts/jetstream "NATS Documentation, JetStream"
[3]: https://redis.io/docs/latest/develop/data-types/streams/ "Redis Documentation, Streams"
[4]: https://www.postgresql.org/docs/current/libpq-notify.html "PostgreSQL Documentation, Asynchronous Notification"
[5]: https://docs.rs/axum/latest/axum/ "docs.rs, axum"
[6]: https://docs.rs/magnus/latest/magnus/ "docs.rs, magnus"

---

References: [1] SHACL specification, [2] NATS JetStream docs, [3] Redis Streams docs, [4] PostgreSQL NOTIFY, [5] PyO3 & Axum bindings, [6] Magnus Ruby bindings.
