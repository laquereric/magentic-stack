<!--
STATUS: frozen / superseded in place
effective: 2026-08-29
superseded-by: docs/adr/0041-two-shape-gems-role-not-namespace.md
governing-decision: ADR 0041 (two shape gems, role not namespace)
also: ADR 0042 (close the Ruby to the TTL; not this freeze), ADR 0043 (retain unreachable shapes)
This document is retained as historical and normative prose.
New protocol requirements are not added here.
New shape development: gems/osi-level-8-profiles (current SHACL package) and
gems/shapes-level-8, gems/shapes-application (packaging homes).
Do not delete. Do not move into a gem.
-->
<!--
Gap analysis drafted by the Manus cloud agent (task 35imP772Pot3ssWAdPE33o), 2026-08-18.
Review-ready; citations reflect Manus research and are not independently verified.
Question: is osi-level-8 the formal enterprise-AI "language" Enrique Dans argues for?
-->

# GAP ANALYSIS — Is osi-level-8 “that language” for enterprise AI?

Executive summary
- The analysis evaluates whether OSI Level 8 (osi-level-8) constitutes Enrique Dans’s vision of a formal enterprise-AI language, i.e., a thin, portable language/grammar that makes the AI substrate productive by encoding persistent state, durable execution, governance, observability, and learning into the interface itself. The strongest conclusion supported by the public specification and profiles is: (b) osi-level-8 is the grammar of that language, but not yet the complete language. In other words, osi-level-8 provides a robust interface grammar for governed perception and action, but the explicit, default, enterprise-wide properties Dans envisions (persistence by default, durable execution, a universal biography/journal, native observability, and a native learning loop tied to business outcomes) are not mandated by the base spec and remain in Profiles and runtime implementations. Evidence from the base spec, Profiles 1–3, and related runtimes supports this stance. [1] [3] [4] [5] [6] [7] 

Scope and method
- This analysis grounds claims in public primary sources: the osi-level-8 base specification, the three published profiles (Profile 1: Cyborg Channel, Profile 2: NOOA/reference-passing, Profile 3: SwitchYard), and the MagenticRuntime family described in the public repositories. It compares Dans’s requirements (as expressed in his Medium article and Fast Company piece) to the normative statements in the base and profiles. The Medium article is textually protected in places, but accessible summaries and canonical quotes are used to ground the thesis; the Fast Company article provides parallel articulation. The MagenticRuntime materials are used to assess how the surrounding stack enacts or fails to enact the “default-by-default” properties. [1] [2] [3] [4] [5] [6] [7]

Key sources reviewed
- Enrique Dans, Enterprise AI doesn’t need another app: it needs its language (Medium) [1]
- Enrique Dans, Enterprise AI doesn’t need another app: it needs its language (Fast Company) [2]
- OSI Level 8 Base specification (README and base doc) [3]
- OSI Level 8 Profile 1: The Cyborg Channel [4]
- OSI Level 8 Profile 2: Reference-Passing for Agents [5]
- OSI Level 8 Profile 3: Market Routing (SwitchYard) [6]
- Magentic Runtime architecture and runtime repository [7]

Property-by-property scorecard
Legend: NATIVE = property is mandated/normalized by the base spec; ADJACENT = supported by profiles/runtime but not mandated by the base; MISSING = not established as a portable language property in the base or profiles.

| Required native property | What osi-level-8 base/spec alone provides | Evidence from published specifications | osi-level-8 + companion/runtime | Gap assessment |
|---|---|---|---|---|
| Persistent agents / persistent operational state by default | ADJACENT | Base defines three ledgers (CANONICAL, SYNC_INTENT, PRIVATE_LOCAL) with implementation-specific storage; base places no constraint on decision agents or persistence across sessions. Profiles describe data models but do not mandate persistent agent continuity. | ADJACENT | No portable, language-level persistence mandate exists in the base; runtime profiles may implement persistence, but it is not a normative language property. See base and Profile 1/2 discussions. [3] [4] [5] |
| Durable execution by default | ADJACENT | The base requires durable association of operationId and permits durable delivery via transport (JetStream as an option). However, a durable run lifecycle (long-running durability across crashes, restarts, etc.) is not mandated by the base. | ADJACENT | Durability is enabled by runtime/infrastructure (e.g., queues, pods), not a normative language construct in the base. [3] [7] |
| A biography: every meaningful state change becomes part of the system’s record (journal) | ADJACENT | The base requires provenance and auditability; Profile 1 maps changes to typed events or graphs; no canonical, portable, append-only biography model is mandated. | ADJACENT | A portable, interchangeable biography/log ecosystem is not codified as a Level 8 language property in the base; RES-like runtimes could supply this, but it is not normative. [3] [4] |
| Permissions, constraints, auditability as structural properties | NATIVE | The base codifies grounded Context/Effect, SHACL-based validation, closed shapes, and provenance. These are structural properties of the interface; enforcement is part of the grammar/spec and supported by Profiles. | NATIVE / ADJACENT | The base provides strong structural governance (SHACL, closed shapes). However, a full enterprise authorization model (principals, credentials, delegation, revocation) remains a runtime concern; Profile 2/3 add policy governance but do not standardize an end-to-end enterprise IAM. [3] [5] [6] |
| Business outcomes as reward signals the system learns from (observe -> act -> measure -> learn -> improve) | MISSING | The base supports a learnable loop in principle (Context → Effect → observable outcomes), but it does not mandate business-outcome learning or a defined measurement/evaluation/reward loop. Profiles include UsageMetric in SwitchYard, but it is limited to routing/telemetry rather than enterprise-wide learning. | ADJACENT | The learning/reward loop is not established as part of the language; it remains a runtime/profile concern. [3] [6] |
| Native state, context, identity, permissions, durability, observability, feedback, governance | MIXED | Base defines Context, Effect, identity concepts, and governance primitives (SHACL, ledgers) but many elements (native observability and a complete, portable feedback/observability model) are not codified as native language semantics. Profiles cover specific pieces; runtime components extend semantics. | ADJACENT to Native | Observability and a comprehensive feedback/observability model require runtime/backing telemetry; not a single portable language artifact in the base. Governance is strong but not a complete enterprise policy federation model in the base. [3] [6] [7]

Strongest case for osi-level-8 mapping to Dans’s language
- The strongest alignment is that osi-level-8 provides a disciplined, transferable boundary grammar for perception (Context) and action (Effect) with explicit grounding (JSON-LD @context, @id, @type) and conformance through fixed SHACL shapes. The “Cyborg Channel” framing and the three ledgers establish a concrete model for separating truth (CANONICAL), intent (SYNC_INTENT), and private reasoning (PRIVATE_LOCAL). This corresponds closely to Dans’s metaphor of a thin, formal language that makes the AI substrate productive and repeatable, rather than glue-code per app. The base provides the structural grains and conformance mechanisms to support Dans’s thesis, albeit without universal default persistence, universal biography, or a native business-outcome learning loop. [3] [4] [5] [6] [7] 

Strongest case against (and the explicit gaps)
- Dans’s core claim includes default persistence of agents, durable execution across failures, a universal, auditable biography, full observability, and a native, business-outcome learning loop. The base spec does not mandate these; it specifies boundaries, conformance, and governance, but leaves runtime, storage, and learning mechanisms to profiles and implementations. Specifically:
  - Persistent agents and default durability are not mandated by osi-level-8 base; Profile 1/2 describe data models and governance but do not standardize a persistent agent lifecycle. [3] [4] [5]
  - A universal biography/journal with replayable, verifiable history is not codified as a portable language contract; it is discussed as a possible runtime pattern and is not required by base conformance. [3] [4]
  - Observability and business-outcome learning semantics are not encoded as native, portable language features; UsageMetric in Profile 3 is a routing/telemetry feature, not a universal learning loop. [6]
- The Magentic runtime and RES/mmg-observe components are not verifiably public in all details; public sources show the runtime architecture but do not establish portable, base-level semantics for durability, biography, and learning that would qualify as language properties across deployments. [7] 

Concrete recommendations to move osi-level-8 toward Dans’s complete language vision
- Define a new, normative Profile 4 (Durable Cyborg Execution) that formalizes a durable run lifecycle, including runId, checkpoints, retry/compensation plans, and terminal receipts, with verifiable interface contracts and corresponding SHACL shapes.
- Define a Profile 5 (Biography and Provenance) that standardizes a portable, append-only or verifiable-bounded-event log with explicit causality links (actor, version, prior state, decision, outcome, time) and explicit reconstruction rules, with conformance tests.
- Define a Profile 6 (Enterprise Authorization Evidence) that standardizes portable authorization artifacts (Principal, Delegate, CredentialRef, PolicyRef, AuthorizationDecision, Consent, Revocation) with explicit binding to Context/Effect and policy version, plus portable governance semantics.
- Define Profile 7 (Observation and Outcome) that codifies business-outcome measurement and evaluation, including Objective, MetricDefinition, OutcomeMeasurement, Evaluation, and ImprovementDecision, with a defined attribution window and testable loops that tie outcomes to Effects.
- Establish a formal testing regime for conformance across profiles, including end-to-end durability tests, journal reconstruction tests, and cross-profile interoperability checks, ensuring that the same base grammar yields identical semantics across different runtimes.
- Clarify the relationship between the base and runtime components (e.g., MagenticRuntime) in official documentation to avoid attributing runtime capabilities to the base language. This would require explicit, published mappings of runtime properties to the normative profiles. [3] [7]

Crisp verdict
- The answer to whether osi-level-8 is the formal enterprise-AI language described by Dans is: (b) osi-level-8 is the GRAMMAR of that language, but not yet the complete language. The base spec provides the essential grammar and governance primitives that Dans advocates for, but the default properties—persistent agents, durable execution, a universally accessible biography, native observability, and an end-to-end business-outcome learning loop—are not mandated by the base. These properties appear in profiles and runtime implementations, but they are not portable, default language properties at the base level. [1] [3] [4] [5] [6] [7] 

Synthesis and actionable path forward
- To elevate osi-level-8 to the complete enterprise-language envisioned by Dans, the community should publish and adopt a formal profile family (Profiles 4–7) that codifies: (i) durable agent execution, (ii) a portable biography/log, (iii) enterprise authorization evidence, (iv) an outcome-focused learning loop, and (v) a portable observability framework with causal tracing. Profiles would include closed SHACL shapes, a canonical JSON-LD context, normative state-transition tables, and cross-binding tests. The base should remain intentionally lean, with the profiles carrying the operational semantics; that preserves transport- and deployment-neutrality while enabling enterprise-grade guarantees.

Key takeaways
- The osi-level-8 base establishes a strong, portable grammar for context, effect, grounding, conformance, and governance, and it is aligned with Dans’s call for a language rather than another app. The major gaps—persistence by default, durable execution, universal biography, integrated observability, and a business-outcome learning loop—are not mandated by the base and thus reside in profiles/runtime. This creates a credible, testable path from grammar to full enterprise-language capability via a profile ecosystem rather than forcing a single monolithic standard. [3] [4] [5] [6] [7]

References
- Dans, Enrique. Enterprise AI doesn’t need another app: it needs its language (Medium). https://edans.medium.com/enterprise-ai-doesnt-need-another-app-it-needs-its-language-b9ca73056098
- Dans, Enrique. Enterprise AI doesn’t need another app: it needs its language (Fast Company). https://www.fastcompany.com/91584370/enterprise-ai-doesnt-need-another-app-it-needs-its-language
- OSI Level 8 Base (GitHub). https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-base.md
- Profile 1: The Cyborg Channel (GitHub). https://github.com/laquereric/JSON-RPC-LD-PS1-P1/blob/main/spec/profile-1-cyborg.md
- Profile 2: Reference-Passing for Agents (GitHub). https://github.com/laquereric/JSON-RPC-LD-PS1-P2/blob/main/spec/profile-2-nooa.md
- Profile 3: Market Routing (SwitchYard) (GitHub). https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-profile-3-switchyard.md
- Magentic Runtime (GitHub). https://github.com/laquereric/magentic-runtime
- SHACL shapes repository note (README). https://github.com/laquereric/osi-level-8/blob/main/shapes/README.md

Notes
- This report reflects the public, review-ready materials available as of Aug 18, 2026. Where runtimes or non-public components are named (e.g., RES, mmg-observe, Flexible Determinism), the analysis marks them as runtime/architecture claims and not as base-language properties until independently verifiable public material is provided.

End of memo.
