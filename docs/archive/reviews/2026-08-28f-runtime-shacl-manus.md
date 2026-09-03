<!-- Manus advisory, harvested 2026-08-28 from task dN88nyJaSKFD82wJLyD7NH.
     How to make the Level 8 type system enforce SHACL at request time.
     Brief: magentic-market-ai/.mm_tmp/manus/runtime-shacl-brief.md
     Companion: ../architecture/SHAPES.md, which documents the current two-artifact state.
     STATUS: RECOMMENDED, NOT APPROVED. No implementation authorized by this file.

     RECOMMENDATION IN ONE LINE: do NOT run a SHACL interpreter in the request
     path. Generate Ruby from the TTL at build time for the bound subset; keep
     pySHACL as a CI/shadow oracle; consider a Rust engine only later, behind a
     sidecar. This is the "generate Ruby and never execute SHACL in-process"
     outcome the brief named as legitimate.

     VERIFIED at harvest (2026-08-28), all HTTP 200:
       github.com/ruby-rdf/shacl · rubygems.org/gems/shacl · docs.rs/oxirs-shacl
       github.com/cool-japan/oxirs · github.com/RDFLib/pySHACL
     No fabricated citations in this one.

     GAP FILLED BY THE HARVESTER. The brief asked for licence and maintenance
     status per library; on the pivotal Ruby engine the report only said signals
     "vary by repository". The actual RubyGems metadata for the `shacl` gem:
       version 0.4.3, released 2025-06-24, licence **Unlicense**, 577k downloads.
     The Unlicense is a public-domain dedication -- worth a deliberate look given
     this repo ships Apache-2.0 and LicenseRef-DataYoursSoftwareMine-1.0, even
     though the recommendation is not to depend on it at runtime.

     UNVERIFIED: every performance claim is an order-of-magnitude estimate. The
     report says so, and says to measure. Nothing here has been benchmarked. -->

# Making the type system enforce SHACL at runtime in Ruby/Rails

## Executive summary
This design recommends keeping a standards-aligned SHACL processor in CI/shadow as the authoritative source of truth, while generating an in-process, TTL-driven Ruby validator that executes at request time for the bound subset of shapes. The goal is to have one executable definition of a type: the TTL-driven, build-time-compiled Ruby validator. A separate standards-oriented validator (e.g., pySHACL) can run in shadow/CI to verify drift and to adjudicate disagreements, but must not be relied upon as the live gate for admission. This approach minimizes runtime latency, preserves RFC SHACL semantics for the bound subset, and provides a clear migration path with equivalence testing, observability, and governance for unbound shapes.

> Rationale in brief: SHACL semantics apply to RDF graphs and shapes graphs; the current request path is a JSON Hash. The system should project the JSON input into an RDF-like representation for SHACL validation, compile the bound subset into Ruby, and enforce it with a clearly defined executable artifact. If a shape cannot be compiled for runtime, route it to a standards oracle in CI/shadow instead of silently relaxing the rule [1]. A pure-Ruby SHACL engine exists for Ruby (with core SHACL support) but carries performance and feature limitations; therefore, the recommended live path is generated Ruby from TTL rather than an in-process interpreter for general SHACL [2]. In parallel, offload to a Rust-based engine or Python-based validator behind a sidecar only when necessary and controlled by policy, not as the default gate [4] [8].

## 1) Design choices: engine options, costs, and a recommended path
- Core recommendation: Build-time code generation from the canonical TTL shapes to a Ruby validator that runs in the Rails process. The TTL shapes define which constraints are enforceable at runtime (e.g., sh:minCount, sh:maxCount 0, sh:in, sh:minInclusive/sh:maxInclusive, sh:minLength, sh:closed), and the Ruby generator should emit a deterministic validator for exactly those constraints. If a shape requires features beyond the compiled subset (e.g., sh:node, sh:or, SPARQL-based constraints), those shapes must be rejected at build time or diverted to a standards-processor path in CI/shadow; they must not silently execute in the live path [1] [2].
- Standards oracle in CI/shadow: pySHACL (Python-based SHACL validator) remains the primary external validator for conformance testing and drift detection. It provides a broad surface, including SHACL-Core and SHACL-SPARQL, and can be run in isolated processes to avoid impacting request latency in production. This separation keeps the server lean while preserving conformance checks in a safe, observable environment. pySHACL is Apache-2.0 licensed and widely used in the SHACL community; use it as the drift-and-evidence oracle in CI [3].
- Rust-based engines and FFI sidecars: Consider Rust-based SHACL engines (e.g., oxirs-shacl) behind a sidecar or as an optional gated path for shapes that cannot be compiled into Ruby. While these engines promise performance and feature breadth (Core + SPARQL features), they introduce deployment complexity, governance considerations, and require solid equivalent-testing plans before becoming a live gate. Treat them as an optional later-stage option after the initial Ruby-generated path proves stable and safe [4] [8].
- JSON/RDF boundary: Implement a canonical JSON-to-RDF projection for admission requests. The project must declare how JSON input maps to RDF-like terms (focus nodes, predicates, datatypes) so that the generated Ruby validator and any standards validator compare on the same semantic basis. JSON-LD is a valuable standard for serializing Linked Data, but framing must be used carefully and only when there is a stable context and processing semantics; it should not replace the canonical projection contract used for runtime validation [6].
- Runtime safety: Do not rely on Ruby’s built-in Timeout alone for security boundaries; use a supervised worker or a clearly bounded in-process validator with explicit resource limits for any untrusted or unbounded processing. Timeout in Ruby is not a guaranteed hard boundary for untrusted code; treat timeouts as soft containment signals and rely on process boundaries for hard containment [7].
- Summary of recommended path: (a) build-time TTL→Ruby codegen for the 11 bound shapes and any additional shapes the project commits to support; (b) keep a standards validator (pySHACL) in CI/shadow to verify equivalence and drift; (c) if future needs demand additional SHACL features, either extend the codegen with explicit rules or delegate to the shadow validator with a clear policy; (d) ensure shape_digest is tied to the executable artifact rather than the shape TTL path to preserve evidence integrity.

| Decision | Recommendation | Rationale |
|---|---|---|
| Synchronous runtime engine | Generated Ruby from TTL | Lowest per-request overhead, no IPC, deterministic behavior from a known artifact |
| Standards oracle | pySHACL in CI/shadow | Broad surface, explicit maturation tests, non-live gate |
| Native/Rust engine | Consider later behind sidecar | Higher deployment risk and maturity concerns; use only after proven equivalence and governance |
| JSON/RDF boundary | One canonical projection before compiling | Ensures SHACL semantics align with the selected runtime model |
| Build-time artifact policy | Hash and lock the executable artifacts | Prevents drift, ensures reproducibility |
| Existing handwritten branches | Maintain as shadow oracle during migration | Provides historical behavior while proving equivalence |

## 2) The JSON/RDF execution model and digest contract
- Canonical request projection: Introduce request-rdf/v1 as the canonical projection from the incoming JSON-RPC request into an RDF-like structure. This projection defines a stable focus node, maps permitted keys to RDF predicates, and encodes scalars, arrays, and nested objects with deterministic rules. This projection is the contract against which both the generated Ruby validator and the standards oracle are measured. JSON-LD framing is optional and should not be treated as a substitute for the canonical projection unless its context is codified and versioned [6].
- Digest contract: Define an immutable executable artifact digest computed from the canonical source shapes, the generated Ruby code, and the projection contract. Key digest fields include:
  - source_digest: hash of the canonical TTL-shape bundle used to drive generation
  - program_digest: hash of the generated Ruby validator bytes
  - contract_digest: hash of the projection specification + compiler version + relevant config
  - executable_digest: hash over the manifest, source_digest, program_digest, and contract_digest
- Boot-time checks: On boot, load a signed/verified manifest and the corresponding executable; fail boot if the embedded digest does not match the loaded artifact. Do not allow dynamic TTL files to influence runtime decisions post-boot. The shape_digest field will be replaced by executable_digest to reflect the actual running rule [1].

## 3) Migration plan: phases, evidence, and governance
- Phase 0 — Inventory and binding: Produce a machine-readable binding manifest for every TTL shape, including ownership, target, and test policy. Classify each shape as bound_runtime, bound_ci_only, external_binding, deprecated, or unowned. This creates explicit provenance and avoids silent drift [1].
- Phase 1 — Projection contract: Implement request-rdf/v1 and a deterministic normalized input fixture set. Ensure RDF output is deterministic and that fixtures cover absent/null/empty/scalar/array/nested/unknown-key cases. Establish a drift-evidence fixture alignment between Ruby-generated validators and pySHACL.
- Phase 2 — Shape build and manifest: Parse TTL roots, resolve authoritative shape sources, validate syntax, reject duplicates, and generate a manifest that records provenance. Any missing bindings or conflicts result in boot-time rejection or a CI-only artifact depending on policy. This phase establishes a single source of truth for shape definitions.
- Phase 3 — Primitive compiler: Implement a deterministic Ruby code generator for the currently used constraints and closed shapes. The generator should not execute dynamic code on request; it should rely on static, verified constraint components and a fixed computation model. For unsupported features (sh:node, sh:or, SPARQL constraints, recursion), the policy must be explicit: either compile them with a tested path or route to the standards oracle and mark as not admissible for the live gate.
- Phase 4 — Shadow mode: Run the generated validator and handwritten Ruby side-by-side on the same normalized input to detect disagreements. Record disagreements with shape ID, digests, projection version, and timing. Do not let a single disagreement automatically retire a branch; require a stopping rule based on coverage + zero unexplained disagreements over a pre-defined observation window.
- Phase 5 — Replay and mutation: Replay a corpus of known-good and boundary traffic; generate synthetic cases for unexercised shapes. Define concrete acceptance criteria for each shape’s boundary behavior.
- Phase 6 — Canary authority: Enable generated Ruby as the authority for one shape at a time, with the old handwritten Ruby still observing as a reference. Collect metrics (latency, refusals, disagreements) and ensure they stay within tolerances.
- Phase 7 — Retirement: Only retire handwritten branches once all constraints have demonstrably moved to the generated artifact and shadow-mode evidence meets stopping criteria. Attach an evidence bundle for auditing.
- Phase 8 — Unsupported features: Route declared unsupported features to a tested isolated processor or keep them non-admissible with explicit owner and test policy; never quietly accept them. Maintain fail-closed semantics for unsafe shapes.

## 4) Shadow-mode equivalence and stopping rule
- Equivalence requires identical accept/refuse decisions for the same canonical input projection, across all supported shapes and constraints. Record disagreement data with shape ID, digests, projection/compiler versions, decision pairs, and a salted fingerprint of the request. The stopping rule is coverage plus zero unexplained disagreements over a pre-agreed observation window (e.g., a defined traffic volume and time horizon). Shapes with real traffic that never exercises must have generated test cases and synthetic fixtures to exercise boundary conditions.
- Retirement criteria: A shape is eligible for retirement only when every supported constraint has generated positive/negative/boundary fixtures, every handwritten decision branch has witnesses on both sides, and the standard oracle agrees on the projection for the shape’s supported features. Canary observations must show zero unexplained disagreements during the window.

## 5) Governance of unbound shapes
- Do not call the 33 unbound shapes dead or aspirational without evidence. Maintain a binding registry with states: bound_runtime, bound_ci_only, external_binding, deprecated, unowned. Each shape must have an owner, a source package, a target class/operation, and a test policy. An unowned shape denotes a release failure; ci_only is allowed only if the manifest records it as not an admission contract. Implement explicit binding-discovery tests that compare operation declarations, adapter wrappers, and shape manifests. The drift population is to be reported as a coverage metric rather than an overall conformance claim [1].

## 6) Failure semantics and Rails process safety
- The boundary contract must stay data-only in all inter-process communication: {ok: true, ...} or {ok: false, reason:, because:}. If the validator raises, boot must fail or the system must produce a deterministic, safe refusal with a correlation ID. On timeouts or resource exhaustion, return a stable, fail-closed refusal and trigger circuit-breakers. Do not expose internal exceptions to the client. Ruby’s built-in Timeout is not a hard security boundary; use a separate, supervised worker or a bounded in-process validator with strict resource-limits for potentially untrusted code [7].

| Failure type | Boot-time behavior | Request-time behavior |
|---|---|---|
| TTL parse or shape validation failure | Fail boot; do not serve admission traffic | Not applicable |
| Digest mismatch or missing artifact | Fail boot; do not fall back to handwritten Ruby | Not applicable |
| Unsupported SHACL feature | Fail build unless a formal fallback policy exists | If fallback unavailable, refuse with a deterministic fail-closed response |
| Validator exception | Alert and record; boot failure if fatal | Return a grounded refusal with a correlation ID; avoid stack traces |
| Deadline exceeded | Treat as hard containment; kill/isbounce worker | Grounding validator timeout; backpressure until healthy |
| Resource exhaustion | Fail fast; enforce input and size bounds | Return stable invalid-request refusal |
| Shape bundle unavailable | Boot-time failure | Refuse closed; do not read mutable alternate path |

Note: Timeout-based boundaries are not guaranteed hard limits in Ruby; treat them as soft signals and rely on process isolation for untrusted work [7].

## 7) Costs and measurement plan
- Since no explicit latency budget is provided, establish a measurement baseline from current production metrics and allocate costs across normalization, projection, validation, and digest management. Benchmark across the following paths: (a) Generated Ruby, (b) handwritten Ruby SHACL, (c) pySHACL standards oracle, and (d) a Rust sidecar/FFI path if used later. Measure p50/p95/p99 latencies, memory usage, allocations, and per-request overhead. Also measure boot-time costs for artifact loading and factory generation.
- Expected cost profile (order of magnitude): Generated Ruby offers the lowest per-request cost with stable latency; pySHACL adds IPC and Python startup overhead; Rust sidecars add IPC overhead but can provide the best throughput for large payloads; in-process Ruby shacl has the highest risk of variability and performance concerns. These estimates should be validated against real traffic and unit/ensemble tests [2] [3] [4] [8].

## 8) Limitations and honest disclosures
- This design does not claim to produce a fully standards-complete SHACL processor in-process. It provides a path to produce a trusted, executable validator for a versioned subset of TTL constraints, with explicit governance for unbound shapes and a strong separation between the live gate and conformance testing. Running the W3C SHACL test suite in CI remains essential to demonstrate conformance and to guide future feature expansions [1].
- JSON input is not RDF by default; a defined, versioned request RDF projection is mandatory to preserve SHACL semantics during runtime validation. JSON-LD can be used for serializing RDF data but framing must be versioned and explicit to avoid drifting semantics [6].
- The existence of multiple TTL trees and possible governance conflicts (e.g., Profile 9 vs canonical package) must be resolved through a single authoritative manifest. Do not permit two sources to define the same shape without provenance and reconciliation records [1].

## 9) Sources

- Shapes Constraint Language (SHACL) - W3C Recommendation: core semantics for validating RDF graphs against shapes graphs. [1]
- SHACL for Ruby (ruby-rdf/shacl) - pure-Ruby SHACL engine with Core support and partial SHACL-SPARQL; licensing and maintenance signals vary by repository. [2]
- RDFLib/pySHACL - Python-based SHACL validator with broad feature support; IPC-based runtime cost and non-trivial integration considerations. [3]
- oxirs-shacl - Rust-based SHACL engine with Core + SPARQL features and performance optimizations; used as potential future path. [4]
- RubyGems: shacl gem metadata (license, version cadence, and Ruby requirement). [5]
- JSON-LD 1.1 - W3C Recommendation; JSON-LD framing semantics and relationship to RDF data; framing is not a substitute for a canonical RDF projection in runtime validation [6].
- Ruby Timeout library - practical guidance on how timeouts work and their limitations in a live web process; used to justify the need for supervised worker isolation for hard boundaries [7].
- Oxirs repository (cool-japan/oxirs) - production-ready Rust-based RDF platform with SHACL tooling and governance considerations; maturity signals noted in release notes. [8]

### References

[1] Shapes Constraint Language (SHACL) - W3C Recommendation, 2017. https://www.w3.org/TR/shacl/
[2] ruby-rdf/shacl - SHACL for Ruby (pure Ruby), license and maintenance notes. https://github.com/ruby-rdf/shacl
[3] RDFLib/pySHACL - Python SHACL validator with CLI/API. https://github.com/RDFLib/pySHACL
[4] oxirs-shacl - Rust SHACL engine docs. https://docs.rs/oxirs-shacl
[5] RubyGems SHACL gem metadata. https://rubygems.org/gems/shacl
[6] JSON-LD 1.1 - W3C Recommendation. https://www.w3.org/TR/json-ld11/
[7] Ruby Timeout documentation. https://ruby-doc.org/3.4.1/stdlibs/timeout/Timeout.html
[8] Oxirs repository (cool-japan/oxirs). https://github.com/cool-japan/oxirs
