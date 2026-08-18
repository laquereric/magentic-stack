<!--
Preliminary design drafted by the Manus cloud agent (task 3Tf2s2P5jpyRGwdb2Jfnoq), 2026-08-18. Review-ready; not independently verified. Referenced topology PNG is a Manus artifact, not included here.
-->

# Magentic POC — Preliminary Design

**Status:** Preliminary architecture and POC design; **not** an implementation specification and contains no code.  
**Author:** Manus AI  
**Date:** 18 August 2026  
**Scope:** The five-container MIND model, a follow-the-upstream boundary for NOOA and SwitchYard, and an OSI Level 8 grounding thesis.

![Five-container Magentic topology](magentic_five_container_topology.png)

## Executive Position

Magentic should not compete with frontier agent runtimes by attempting to freeze, fork, or reimplement them. The MIND is the Magentic-owned agentic/cognition layer and container. It hosts NVIDIA NOOA exactly as NVIDIA publishes it. NOOA remains the upstream concept and runtime that Magentic follows; it is not renamed, absorbed, or forked. SwitchYard is treated in the same way: an upstream model-routing dependency, not the enterprise semantic system of record.

The thesis is that frontier-agent concepts will continue to change more quickly than a governed enterprise can safely replatform. Kapil Ahuja describes three reframings inside roughly ninety days—from loop engineering to graphs to context-engineering rules—and frames the missing role as a bridge between frontier change and enterprise delivery [1]. Enrique Dans argues that enterprise AI needs a productive language that makes repeatable, safe, economical operation possible rather than another hand-assembled application [2]. Magentic leads that bridge by providing grounding.

__Grounding__ is the deliberate conversion of an ephemeral agent run into governed, typed, durable, attributable, reviewable enterprise state and effects—without making the enterprise depend on the agent runtime.

OSI Level 8 supplies the preliminary grounding grammar: a Cyborg reads Context and has Effect, expressed through JSON-RPC-LD and constrained by SHACL shapes [5]. CPCP supplies the versioned, CID-grounded PULL/PUSH packaging and deployment discipline for that grammar [7]. The stable Magentic asset is therefore the Rails + CPCP + OSI Level 8 grounding plane, not a private derivative of NOOA or SwitchYard.

| Design decision | Preliminary decision | Consequence |
| --- | --- | --- |
| What MIND means | The Magentic-owned cognition layer/container and its stable harness, boundary, and observation projection. | MIND is not a synonym for NOOA and does not claim ownership of NOOA. |
| How NOOA is used | A pinned, unmodified NVIDIA-published release runs inside MIND’s isolated runtime. | Upstream changes are followed through release swaps, never by a Magentic fork. |
| How SwitchYard is used | A pinned, unmodified NVIDIA-published router sits behind an MIND-owned egress adapter. | Provider APIs and routing changes cannot become BACK, GRAPH, or FRONT contracts. |
| Where durability and truth reside | BACK persists durable operational records; GRAPH holds grounded RDF semantic truth and biography. | NOOA live objects and loop state are never durable truth. |
| Public enterprise seam | A fixed, CID-versioned CPCP/OSI Level 8 contract at BACK ↔ MIND. | The POC can replace upstream releases without changing FRONT, BACK, BackJob, or GRAPH semantics. |

## 1. Architecture Thesis and Non-Negotiable Boundaries

The five containers form a governance pod around a volatile runtime. The design intentionally makes the stable enterprise surface larger than the unstable agent surface. FRONT, BACK, BackJob, and GRAPH are Magentic-owned containers with durable enterprise responsibilities. MIND is also Magentic-owned, but its role is deliberately narrower: it contains the as-published NVIDIA runtime, mediates the stable contract, enforces the execution perimeter, and produces a bounded observation projection. It does not become a second persistence plane or a new public protocol.

NOOA’s public model makes this separation especially important. NOOA represents an agent as a Python object whose typed fields represent state, ordinary methods represent capabilities, docstrings are instructions, and ellipsis bodies invoke an LLM-driven loop; the model may act by writing Python in a REPL-like environment [3]. That is useful upstream research and a strong reason to keep NOOA’s live object graph contained. It is not an acceptable long-lived enterprise record format or authorization surface.

The following constraints are architectural invariants for the POC:

| Invariant | Required interpretation |
| --- | --- |
| Follow without coupling | Pin and run NVIDIA releases as published; swap only at the MIND adapter seam; do not copy or modify NOOA or SwitchYard source. |
| One public semantic surface | /_cpcp remains the public CPCP surface. rails-osi-level-8 is a semantic adapter atop CPCP, not a competing RPC API. |
| No durable live heap | A NOOA object, its Python references, REPL locals, and iteration state remain transient inside MIND. Only a bounded, typed projection may cross the boundary. |
| No direct MIND persistence | MIND receives no Rails database credential and no direct GRAPH write access. It returns proposals and observation projections to BACK. |
| Effects are proposed before committed | A model-produced result is an Effect proposal until BACK validates its CID/profile, policy, authorization evidence, and any required human gate. |
| Governance is semantic, not prompt-only | Network, credential, capability, schema, and human-gate controls enforce governance outside the NOOA prompt and Python object. |
| Upstream is replaceable evidence | Every run records its NOOA, SwitchYard, adapter, CID, profile, and policy identities so behavior can be traced and compared across releases. |

## 2. Five-Container Topology

The topology below is the proposed POC boundary. SwitchYard and model providers are intentionally shown outside the five Magentic containers. They may be separately deployed execution units, but they are not a sixth Magentic grounding container; their native interfaces terminate inside MIND.

### 2.1 Container Responsibilities

| Container | Responsibility | Owns | Must not own |
| --- | --- | --- | --- |
| FRONT | UI server for the pod: operational dashboards, a bounded read-only visual of transient MIND state, and authorized views of BACK, BackJob, and GRAPH. | Presentation state, user navigation, filtered read models, visual freshness and redaction indicators. | NOOA control, direct model calls, policy decisions, direct Oxigraph administration, or raw transient object access. |
| BACK | Rails 8 application mounting rails-cpcp and the new rails-osi-level-8 semantic adapter. It is the contract authority, policy decision point, and durable command coordinator. | /_cpcp, CID/profile selection, ActiveRecord Context and Memory, policy and approval records, operation journal, validation status, access control, GRAPH publication intent. | A second RPC surface, a private NOOA object schema, direct dependence on SwitchYard-native response types, or unbounded prompt/transcript storage by default. |
| BackJob | Durable and resumable work governed by BACK: graph publication, retry, timeout handling, outcome collection, reconciliation, and approved external-effect execution. | Idempotent operation progression, retry policy, durable execution receipts, resume state, dead-letter/review state. | Live NOOA loop ownership, UI rendering, or unrestricted execution authority. |
| GRAPH | Oxigraph semantic truth store. It holds grounded RDF for Context, Effects, authorization/provenance links, biographies, observations, outcomes, and architectural-learning records. | SHACL-validated RDF, provenance edges, semantic query support, immutable or append-oriented biography records. | Raw MIND heap snapshots, unvalidated writes, or direct end-user administration. |
| MIND | The Magentic agentic/cognition container. A MIND Harness contains the as-published NOOA runtime, exposes only the stable ingress/egress seam, applies environment controls, and emits read-only bounded observations. | Runtime isolation, upstream release pinning, ephemeral run lifecycle, projection/redaction, adapter compatibility, model-egress mediation. | Durable enterprise state, final policy authorization, direct database/GRAPH access, public protocol definition, or a fork of NOOA/SwitchYard. |

BACK’s rails-osi-level-8 adapter interprets CPCP operations in the Level 8 grammar. It maps Context and Effect semantics, invokes SHACL validation, attaches profile evidence, and coordinates persistence. It does not invent a new endpoint family. This follows the existing rails-cpcp approach of projecting Rails resources as CID-grounded JSON-RPC-LD with /_cpcp, while CPCP itself defines PULL as Context reading and PUSH as typed, closed-shape Effect writing [6] [7].

### 2.2 Interface Map

| From | To | Stable interface and direction | Content permitted | Design guardrail |
| --- | --- | --- | --- | --- |
| FRONT | BACK | CPCP PULL through the BACK authorization facade. | Authorized Context, durable operation status, approved bounded MIND projection, graph-derived read models. | FRONT never queries the NOOA process or raw GRAPH store directly. |
| BACK | MIND | MagenticMindOperation: a fixed, CID-versioned OSI Level 8/CPCP operation contract. | Context references and minimum materialized Context, capability grant, policy digest, run budget, operation identifier, correlation identifiers. | No Rails session, database credential, unrestricted user payload, or provider credential crosses by default. |
| MIND | BACK | Effect proposal and MindObservationProjection returned against the same operation identifier. | Typed effect candidate, bounded snapshot, lifecycle status, redacted error class, evidence digests, release identities. | BACK validates and decides; MIND cannot mark an effect as committed. |
| BACK | BackJob | Durable-operation command and resume event. | Validated operation record, idempotency key, policy decision, approved effect payload reference. | BackJob uses the durable record, not NOOA memory, to resume. |
| BACK | GRAPH | Validated semantic publication and retrieval through the semantic adapter. | RDF Context/Effect/provenance triples, SHACL results, biography and observation records. | A transactional outbox/publication-state pattern is required so AR and GRAPH do not silently diverge. |
| MIND | SwitchYard | MIND-owned egress adapter terminating the native SwitchYard API. | Model request allowed by capability/policy; route metadata and usage evidence returned in minimized form. | SwitchYard’s native API, provider shapes, and routing algorithms never reach BACK as durable application types. |
| SwitchYard | Model providers | Published upstream routing/proxy behavior. SwitchYard translates among supported provider formats and reports operational metrics [4]. | Provider request/response as permitted by MIND egress policy. | Default-deny egress; explicit provider allow-list; no provider is an implicit enterprise authority. |

## 3. The Follow-The-Upstream Boundary

### 3.1 The Boundary Is a First-Class Product Element

The core design object is not merely a compatibility adapter. It is a FollowUpstream Boundary operated by MIND. Its purpose is to make a release of NOOA or SwitchYard an explicit, auditable, reversible runtime selection rather than a library upgrade that leaks through the product.

The MIND Harness owns only three things around the upstream runtimes: ingress translation from the fixed MagenticMindOperation CID; egress translation to the published SwitchYard interface; and non-invasive observation/projection. It does not alter NOOA’s execution semantics, subclass NOOA internals to change behavior, patch a release, or introduce Magentic-only features that require maintaining a fork. The NOOA distribution remains NVIDIA’s published distribution, selected by exact release and immutable artifact identity. The same rule applies to SwitchYard.

NOOA was described in the feasibility material as v0.0.8. The source reviewed for this design reports a newer published v0.0.9 release; therefore, the POC must treat the initial version as an explicit decision—not an implicit “latest” install—and record that decision in every run [3]. A later NVIDIA release may be evaluated and accepted, but it may not silently replace the release that produced a prior biography or effect.

### 3.2 Release Pin, Swap, and Conformance Process

| Stage | Required evidence | Decision outcome |
| --- | --- | --- |
| Pin | UpstreamReleaseRecord containing repository, version/tag, commit, artifact/image digest, dependency lock digest, release date, and adapter version. | A single reproducible NOOA and SwitchYard runtime is selectable for a POC environment. |
| Inspect | Release-note review, license/supply-chain review, declared capability delta, and a Profile 8 assumption/drift record. | Change is classified as compatible, conditionally compatible, or rejected. |
| Conform | Fixed MagenticMindOperation CID, profile set, closed SHACL validation cases, denied-capability tests, bounded-observation tests, and known operation scenarios. | A release can be admitted only if it produces valid contract outputs and fails safely on invalid inputs. |
| Shadow | Matched non-production operations executed against the candidate alongside the current pin, with comparable grounded observations and outcome evidence. | Evidence shows whether semantics, observability, cost, or failure behavior changed materially. |
| Promote | Recorded approval, policy digest, rollback target, and explicit release-selector change. | Candidate becomes the selected upstream release for newly started runs only. |
| Rollback | Selector reverts to prior accepted pin; existing runs retain their originating release identity. | Restoration does not rewrite history or erase biography. |

This process is deliberately governed by the fixed CID and profile conformance, not by testing whether Python objects look the same across NOOA versions. CPCP defines a CID as a JSON-LD context, operation manifest, and closed SHACL shapes; its versioning model provides a natural way to keep the enterprise contract stable while runtime implementations change [7]. The OSI Level 8 repository also explicitly positions its specs and shapes as authoritative over a thin reference surface [5].

### 3.3 What Magentic Adds That Upstreams Do Not

NOOA contributes a useful Pythonic agent model and its own generation/event observability; SwitchYard contributes provider translation, routing algorithms, and operational routing metrics [3] [4]. Neither upstream alone is the enterprise grounding plane proposed here.

| Grounding contribution | OSI Level 8 profile | Magentic POC responsibility | Upstream gap addressed |
| --- | --- | --- | --- |
| Cyborg reads Context and has Effect | Profile 1 — Cyborg Channel | Make Context/Effect the stable unit of enterprise interaction, typed and SHACL-governed. | NOOA object state is runtime-local; provider routing does not define enterprise effects. |
| Reference-passing | Profile 2 | Pass durable Context and payload references rather than copying live Python objects or broad records. | NOOA reference semantics do not create enterprise-safe, durable identity references. |
| Market/model routing evidence | Profile 3 — SwitchYard | Ground a route proposal/decision, policy digest, rationale, offer/version, and content-minimized usage evidence. | SwitchYard routes traffic but does not own enterprise authorization or semantic retention. |
| Durable execution | Profile 4 | Create resumable operations, idempotency, durable state transitions, retry/review behavior, and completion receipts through BACK and BackJob. | A transient NOOA loop is not durable work management. |
| Biography and provenance | Profile 5 | Preserve an append-oriented account of who/what/which release/policy/Context produced a committed Effect. | A trace or object inspector is not a business biography. |
| Enterprise authorization evidence | Profile 6 | Bind policy, identity, approval, effect digest, expiry, and gate decision before commitment or external execution. | Neither a Python docstring nor a routing choice is enterprise authorization. |
| Observation and outcome | Profile 7 | Store bounded run observations and measured business outcome separately from proposed/committed effects. | Generation tracing and routing metrics do not, by themselves, establish business outcome. |
| Architectural learning | Profile 8 | Record release assumptions, drift, reconciliation results, architectural decisions, human checkpoints, and frame-change absorption. | Upstream churn otherwise becomes unrecorded reactive rework. |

The profile names and the Profiles 3–8 roles above reflect the published OSI Level 8 documentation and associated SHACL work, including Durable Cyborg Execution, Biography & Provenance, Enterprise Authorization Evidence, Observation & Outcome, and Architectural Learning Loop [5].

## 4. Transient-State Grounding

### 4.1 Principle: Project, Do Not Persist the Object Graph

NOOA’s typed objects and agentic loop are MIND-local and transient. The POC must not serialize the Python heap, treat a live object reference as an enterprise identifier, mirror arbitrary REPL locals into ActiveRecord, or expose a debugger as a UI feature. Such approaches would couple all downstream components to a young runtime’s implementation details and would materially expand the Python-REPL attack and privacy surface.

Instead, MIND produces a MindObservationProjection: a bounded, read-only, schema-defined view of the run. The projection is generated at explicit lifecycle checkpoints—for example, operation accepted, Context read, generation started, model route returned, effect proposed, gate waiting, terminal success, terminal failure, or timeout. FRONT presents the latest approved projection with its timestamp, freshness, and redaction state; it never presents this view as the durable whole truth of the agent.

> A MIND visual is an instrument panel, not a window into the Python heap. It is designed to answer “what authorized operation is running, what bounded state is it in, what has it proposed, and what gate is pending?” It is not designed to reveal arbitrary object fields, REPL code, raw prompts, secrets, or hidden chain-of-thought-like material.

### 4.2 Read-Only Observation Boundary

The observation design must lean on NOOA’s published generation observability and typed-object model rather than modify NOOA. The MIND Harness launches the pinned NOOA release in its isolated process boundary and subscribes only to supported/public lifecycle or generation-observation signals. It associates those signals with MIND-owned operation identifiers and the small set of typed objects that were explicitly passed through the fixed contract. It then applies a projection policy outside NOOA.

There is no monkey patching of NOOA source, no modification of its loop, no debugger injection, no scanning of arbitrary Python memory, and no attempt to make NOOA objects durable. If a future NOOA release does not expose the needed stable observation signal, MIND degrades safely to a coarser lifecycle projection, marks observation fidelity as reduced, and blocks promotion if the POC’s conformance requirement cannot be met. The system must never compensate by introducing a hidden fork.

| Projection category | May appear in MindObservationProjection | Must not appear by default | Grounding destination |
| --- | --- | --- | --- |
| Identity and lineage | Operation ID, run ID, Context reference IDs, parent operation, NOOA/SwitchYard pins, adapter/CID/profile IDs. | Raw credentials, provider tokens, database keys. | AR operation journal; GRAPH provenance/biography. |
| Loop status | Phase, iteration count, started/updated time, bounded method/capability identifier, terminal class, retry count, resource-budget state. | Arbitrary stack frames, REPL local values, Python object memory addresses. | AR status; GRAPH observation. |
| Typed-object view | Approved object-type name, stable domain reference, allow-listed field labels/statuses, field-presence indicators, redaction markers. | Entire object serialization, hidden fields, unrestricted relationships, implicit live references. | P1/P2 Context link; P7 observation. |
| Model-routing view | Requested capability class, selected model/provider identifier where policy allows, route-decision ID, latency/token/cost class, failure class. | Prompt body, completion body, embedding, telemetry payload, provider secret. | P3 route evidence; P7 observation. |
| Effect view | Effect type, digest, validation state, approval state, external-action state, result reference. | Executable code or raw action payload when the viewer lacks authorization. | P1 Effect; P5 biography; P6 authorization evidence. |
| Security view | Capability grant ID, sandbox policy ID, denied-attempt count/category, gate state. | Security-sensitive policy internals that would aid bypass. | P6 authorization evidence; P7 observation. |

### 4.3 Grounding and Rendering Choreography

1. MIND observes; BACK grounds. MIND emits a bounded projection and an Effect proposal to BACK under the same fixed operation CID. MIND does not write ActiveRecord or GRAPH.
2. BACK validates. The semantic adapter validates the projection and Effect against the selected profile shapes, verifies correlation and release identities, and applies authorization and retention rules.
3. BACK persists operational state. Context/Memory records, operation status, projection receipt, validation result, policy decision, and user gate state are durable in ActiveRecord.
4. GRAPH receives semantic truth. BACK publishes validated RDF Context/Effect/provenance/biography/observation records to GRAPH. A durable publication-state record prevents silent dual-write divergence; until GRAPH confirmation, FRONT displays the grounding state as pending rather than complete.
5. FRONT renders an authorized read model. FRONT PULLs a deliberately shaped view through BACK. It may combine operation status, BackJob status, and graph-derived biography, but it cannot request an arbitrary MIND object or a raw model transcript.

This distinction preserves the design’s central claim: the agent’s current cognitive substrate may be transient, but enterprise meaning is grounded as a controlled projection with provenance.

## 5. Representative End-to-End MIND Operation

The following representative operation demonstrates the required flow. It assumes a policy-governed Cyborg operation where a responsible human may have to authorize the Effect before an external action occurs.

| Step | Container(s) | Event and decision | Grounding result |
| --- | --- | --- | --- |
| 1 | FRONT → BACK | An authorized human selects a bounded task. FRONT requests available Context and capability options via BACK, not from MIND. | BACK resolves the Cyborg’s authorized Context references under Profiles 1 and 2. |
| 2 | BACK | BACK creates MagenticMindOperation with an operation ID, correlation ID, selected fixed CID/profile set, policy digest, budget, NOOA pin, SwitchYard pin, and initial authorization state. | AR holds a durable operation record; GRAPH receives or links the initial Context/provenance record. |
| 3 | BACK → MIND | BACK invokes the fixed CPCP/OSI Level 8 operation contract. It gives MIND only the Context references/material permitted by policy and a scoped capability grant. | MIND receives a bounded input, not a Rails session or direct access to BACK/GRAPH. |
| 4 | MIND / NOOA | The MIND Harness instantiates and runs the unmodified pinned NOOA runtime. NOOA executes its typed-object and harness loop inside the constrained Python environment. | The live object state remains transient within MIND. MIND emits an initial bounded observation. |
| 5 | MIND → BACK → FRONT | At lifecycle checkpoints, MIND returns MindObservationProjection events. BACK validates and grounds them; FRONT updates its read-only visual. | Users see phase, iteration, allowed typed-state labels, budget, and gate status—not the Python heap. |
| 6 | MIND → SwitchYard → model provider | When a model call is needed, the MIND egress adapter calls the selected as-published SwitchYard release. SwitchYard performs its published provider routing/translation function [4]. | MIND returns a content-minimized route/usage observation; Profile 3 links it to policy and operation evidence. |
| 7 | MagenticMindOperation flows to BACK | NOOA’s loop produces an Effect candidate. MIND translates it into the fixed Effect proposal plus projection; it cannot commit it. | BACK validates closed shapes, correlates Context and release evidence, and records the proposal. |
| 8 | BACK → FRONT → human gate | If Profile 6 policy requires approval, BACK places the operation in AwaitingHumanGate. FRONT renders the proposed Effect digest, permitted detail, evidence, and expiration. | The human approval/denial is bound to the effect digest, policy digest, Context version, and operation ID. |
| 9 | BACK → BackJob → GRAPH | On approval—or immediately for a pre-authorized low-risk effect—BackJob executes the durable, idempotent progression. BACK publishes the validated Effect, authorization evidence, and Profile 5 biography to GRAPH. | GRAPH becomes semantic truth; AR records publication/receipt and durable outcome state. |
| 10 | BACK / GRAPH → FRONT | BACK exposes the committed effect, biography, outcome status, and final bounded MIND state. FRONT renders a clear distinction between proposed, approved, committed, failed, and pending-grounding states. | The operation is inspectable without treating MIND’s transient loop as the source of enterprise truth. |

## 6. Containment Posture for the Python-REPL Runtime

The POC treats the NOOA Python-REPL model as a research-preview execution risk, not as a control plane. The security design must be enforced by container/runtime controls and capability boundaries, not by instructions supplied to a model.

| Control domain | POC design posture | Acceptance condition |
| --- | --- | --- |
| Process boundary | NOOA runs in an isolated MIND runtime with a non-privileged identity, immutable/pinned artifact, no host mounts, and resource limits. | A compromised run cannot access host-level credentials, source workspaces, or unrelated tenant data. |
| Network boundary | Default-deny egress; only explicit routes to BACK and approved SwitchYard endpoint(s); provider traffic only through SwitchYard. | Direct Internet, database, metadata-service, and lateral-service access are denied. |
| Credential boundary | Short-lived, operation-scoped tokens only; no Rails database, GRAPH, broad cloud, or provider master credentials in the NOOA process. | A leaked runtime token has narrow scope and expires. |
| Capability boundary | MIND receives an allow-listed capability grant. Any external effect is represented as a BACK-governed proposal, not a callable ambient Python power. | The runtime cannot execute arbitrary business effects merely because model-generated Python requests them. |
| Resource boundary | Iteration, wall-clock, token/cost, memory, and concurrency budgets are set per operation; overrun transitions to durable review/timeout. | Runaway loops have bounded blast radius and a visible terminal state. |
| Observation boundary | Public generation observability plus allow-listed typed projections only; no arbitrary heap inspection. | FRONT has useful status without becoming a covert exfiltration channel. |
| Human/policy boundary | Profile 6 controls bind approval to exact versioned Context and Effect evidence; high-impact actions default to a human gate. | A stale or altered proposal cannot reuse a prior approval. |

## 7. Principal Risks and POC Responses

| Risk | Why it matters | POC mitigation | Evidence to require before proceeding |
| --- | --- | --- | --- |
| Python-REPL escape or unsafe code execution | NOOA’s model-authored Python loop may exercise a broad execution surface [3]. | Isolated MIND runtime, no ambient credentials, default-deny network, capability grants, quotas, and proposal-only effect model. | Denied-egress/capability tests; resource-exhaustion test; privileged-secret absence test. |
| Observation without coupling proves too weak | A public observability surface may change or fail to provide a safe, useful projection. | MIND’s adapter observes only documented/public signals; maintain a minimum lifecycle projection; never fall back to heap scraping or a fork. | Projection conformance test and explicit “reduced fidelity” behavior. |
| NOOA or SwitchYard churn alters behavior | A release may change APIs, output behavior, routing, tracing, or security posture. | Pin exact artifacts; fixed CID/profile conformance; shadow runs; approval, release record, and rollback. | Candidate versus baseline comparison and recorded acceptance decision. |
| Semantic drift or dual-write inconsistency | AR and GRAPH could disagree, obscuring whether an effect is grounded. | BACK owns validation and durable publication state; use an outbox/reconciliation discipline; FRONT shows grounding status. | Deliberate GRAPH publication failure/recovery scenario with no false “committed” display. |
| Sensitive data leaks through UI or route telemetry | The bounded MIND view can accidentally become a prompt/secret/transcript viewer. | Projection allow-list, reference/digest preference, redaction markers, role-filtered FRONT views, content-minimized routing evidence. | Privacy review of each projection field and negative test with synthetic secrets. |
| Policy approval becomes detached from content | A human may approve an obsolete or materially changed action. | Bind approvals to effect digest, Context version, policy digest, expiry, and operation ID; invalidate on material change. | Approval replay/staleness test. |
| Cost, latency, or loop runaway | Iterative agent execution and route selection can create uncontrolled consumption. | Per-operation budgets, timeout/cancel state, Profile 7 usage/outcome observation, and durable review path. | Load and over-budget scenarios terminate predictably. |
| POC is mistaken for production certification | Research maturity plus an agentic REPL runtime require more than a functional demo. | Mark the POC as a contained experiment; produce explicit residual-risk and promotion criteria. | Security, operations, and governance sign-off before any production expansion. |

## 8. Minimal Build Order

The POC should prove the boundary before it proves agent sophistication. Each increment should leave a valuable, demonstrable artifact even if later upstream evaluation stops.

| Order | POC increment | What is stood up | What it proves | Stop criterion |
| --- | --- | --- | --- | --- |
| 1 | Grounding contract baseline | A fixed MagenticMindOperation CID, selected Profile 1–8 shape set, stable Context/Effect/observation vocabulary, and explicit release-record format. | The enterprise contract exists independently of NOOA and SwitchYard. | Contract is ambiguous, unvalidated, or requires runtime-internal types. |
| 2 | BACK + GRAPH truth path | Rails 8 with rails-cpcp, rails-osi-level-8 as an adapter, AR Context/Memory/operation records, and Oxigraph publication/read path. | A Context can be read and a typed Effect/provenance record can be grounded without an agent runtime. | BACK creates a second semantic/RPC surface or GRAPH writes cannot be validated/reconciled. |
| 3 | MIND containment shell | MIND Harness with an exact NOOA pin, constrained runtime, scoped ingress, and proposal-only egress. | NOOA can be run as published behind a stable seam without direct persistence or broad authority. | Any essential design function requires modifying NOOA or bypassing the boundary. |
| 4 | Bounded transient-state projection | Read-only generation/lifecycle observer, MindObservationProjection, BACK validation, and a minimal FRONT visual. | Transient typed-object/loop state can be meaningfully visualized without persisting the heap. | Useful observability requires raw memory, arbitrary REPL contents, or source modification. |
| 5 | SwitchYard egress and routing evidence | Exact SwitchYard pin behind MIND’s egress adapter, one approved model route, Profile 3 route/usage grounding. | Model routing can change upstream without becoming an enterprise API dependency. |
| 6 | Durable, gated effect | BackJob resumption, Profile 4 durable state, Profile 5 biography, Profile 6 human gate, Profile 7 outcome, and one bounded external-effect stub or controlled action. | A NOOA-produced proposal becomes a governed effect only through grounding and authorization. |
| 7 | Follow-upstream rehearsal | A candidate NOOA or SwitchYard release is pinned, conformed, shadowed, accepted/rejected, and rolled back in a non-production environment. | The central thesis works operationally: Magentic can absorb upstream change without replatforming the enterprise surface. |

### POC Definition of Success

The POC succeeds when a responsible user can initiate a single bounded Cyborg operation; FRONT can show an authorized, timely, bounded visual of MIND’s transient run; NOOA runs unmodified in an isolated MIND container; a model call flows through the selected published SwitchYard release; the result is only a proposal until governed; and the committed Effect, approval, release provenance, and outcome can be queried as grounded BACK/GRAPH records. A second upstream release must then be demonstrably admitted or rejected through the fixed CID/profile conformance process without changing the enterprise-facing contract.

## 9. Explicit Non-Goals for This Pass

This preliminary design does not specify container manifests, Python/Rust code, database schemas, API payloads, user-interface design, production deployment architecture, provider selection strategy, performance targets, or a full threat-model certification. It also does not declare NOOA or SwitchYard production-ready, nor does it make the POC a claim that model-generated Python can safely receive broad enterprise execution authority.

The next design pass should refine the exact MagenticMindOperation CID and profile mappings, the projection field allow-list, retention and redaction policy, operational SLOs, threat model, test/conformance catalogue, and human-gate policy taxonomy. Those are refinements of the grounding plane—not reasons to couple the durable enterprise architecture to NOOA or SwitchYard internals.

> References

[1] Kapil Ahuja, “The CTO’s Achilles Heel for AI Adoption: Building the Bridge to the Enterprise,” https://medium.com/activated-thinker/the-ctos-achilles-heel-for-ai-adoption-building-the-bridge-to-the-enterprise-77fe538c66cd.

[2] Enrique Dans, “Enterprise AI doesn’t need another app: it needs its language,” https://www.fastcompany.com/91584370/enterprise-ai-doesnt-need-another-app-it-needs-its-language.

[3] NVIDIA-NeMo, labs-OO-Agents (NOOA), https://github.com/NVIDIA-NeMo/labs-OO-Agents.

[4] NVIDIA-NeMo, SwitchYard, https://github.com/NVIDIA-NeMo/Switchyard.

[5] Eric Laquer, OSI Level 8, https://github.com/laquereric/osi-level-8.

[6] Eric Laquer, rails-cpcp, https://github.com/laquereric/rails-cpcp.

[7] Eric Laquer, cyborg-pod-contract-package / PubSubStandard_1 (JSON-RPC-LD-PS1), https://github.com/laquereric/cyborg-pod-contract-package.

---
Notes: This document is a consolidation of the prior feasibility material, upstream materials, and the 5-container MIND topology. It grounds the design in the thesis statements and explicitly delineates the follow-the-upstream boundary, the transient grounding approach, and the minimal build order needed to prove the concept. The topology diagram and the source repositories cited above serve as anchors for the intended boundary conditions and governance model. For traceability, all upstream bindings (NOOA, SwitchYard, CPCP, and OSI Level 8) are kept as external, publish-once/runtime-swappable components; Magentic owns the enterprise-facing surfaces (FRONT, BACK, BackJob, GRAPH) and the MIND boundary to ensure churn is absorbed without forking upstream runtimes.
