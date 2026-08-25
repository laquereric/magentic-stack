<!--
Feasibility + preliminary architecture drafted by the Manus cloud agent (task PihFvqap7onErRKLF9eTf5), 2026-08-18. Review-ready; not independently verified.
-->

# Magentic POC — Feasibility Assessment and Preliminary Architecture

Scope: This document presents a feasibility assessment and a conceptual, layer-grounded architecture for the Magentic POC. It intentionally omits implementation details, code, migrations, and exhaustive schemas. It treats rails-osi-level-8 and vv-nooa as proposed components, not yet verified artifacts, and anchors the design to public CPCP/OSI Level 8 materials in the references.

Executive feasibility summary
- The layered concept is coherent if OSI Level 8 is treated as the semantic interface grammar (Cyborg reads Context, acts via Effect) and CPCP functions as the CID-based packaging, contract, and frontend/backend pod topology. The public CPCP material maps JSON-RPC-LD surfaces to a pod packaging model that can be layered over the OSI-8 grammar. This separation helps avoid duplicating surface semantics across two engines and aligns with the CPCP practice of a single, versioned surface per profile. See OSI Level 8 and CPCP public materials. [1] [2]
- Two Rails engines (rails-osi-level-8 and rails-cpcp) can coexist if rails-osi-level-8 is deployed as a semantic-adapter within the CPCP boundary rather than exposing a second independent RPC surface. The CPCP engine already provides the public /_cpcp surface and never-raise envelopes; OSI-8 adds the Cyborg-facing semantics and governance. [3]
- Active Record can serve as Context and Memory stores for a POC, provided the architecture preserves an immutable/logical ledger view for canonical context and memory projections, while exposing a separate, bounded visual of the transient NOOA state. This preserves the graph/event-log separation implied by OSI-8 and the CPCP semantics. [9] [2]
- NOOA harness via a separate Python runtime is feasible if isolated from Rails, with a CPCP adapter mediating between OSI-8/CPCP surfaces and the model-callable harness API. Switchyard provides the routing/proxy boundary to select a model provider, but its hosted surface should be treated as a routing layer rather than a direct inference engine behind the CPCP contract. [6] [7] [8]
- A minimal, vertically scoped POC can prove the core composition: one bounded Context read (PULL) from Rails BACK, one NOOA harness loop, one model call routed via a CPCP adapter through Switchyard, and one non-destructive Insight PUSH back to Rails BACK with a durable receipt. This approach mirrors Profiles 1–2 demonstrations while avoiding overextension into full Profile 4–8 capabilities. [4] [5] [3]

Key public sources underpinning the feasibility and architecture decisions
- OSI Level 8 public repository (Cyborg Channel, JSON-RPC-LD, SHACL constraints, Profiles) [1]
- CPCP and its four-container pod concept [2]. NOTE: this line expanded CPCP as "Cyborg Pod Contract Package" -- a THIRD expansion, alongside the PubSubStandard framing the gem itself used to carry. The settled one is **coordination-protocol-contract-package**; see docs/architecture/CPCP.md.
- Rails CPCP repository (mountable engine, /_cpcp, two-pod topology) [3] -- private, not public
- Profile 1 CPCP (Cyborg Channel) and Profile 2 CPCP (reference-passing) concrete examples [4][5]
- NVIDIA Switchyard routing surface and Switchyard hosted surface for routing decisions [6][8]
- NOOA (NVIDIA Object-Oriented Agents) harness architecture and agent capabilities [7]
- Active Record basics (persistence, AR as ORM) [9]

Sources cited in-line: [1] [2] [3] [4] [5] [6] [7] [8] [9]

1) OSI Level 8 — public interface and profile framing
- OSI Level 8 defines the cybernetic interface where a Cyborg reads Context and acts via Effect, using JSON-RPC-LD constrained by SHACL shapes. Profiles define the surface semantics; Profile 1 centers on Cyborg Channel semantics. This provides the semantic language and governance boundary for the Magentic POC. [1]

2) CPCP — public pod contract packaging and surface
- CPCP provides a versioned, CID-backed pod surface with FRONT and BACK OCI images, JSON-RPC-LD envelopes, and never-raise semantics. Profile 1 and Profile 2 material live in their own CPCP repos, with the OSI Level 8 repo holding the base and Profile 3 surface. This clarifies contract authority and layering expectations for the Magentic POC. [2]

3) rails-cpcp — Rails engine for CPCP deployment
- rails-cpcp is a mountable Rails engine that exposes CID-grounded JSON-RPC-LD operations at the /_cpcp surface. It defines the BACK (Rails app) and FRONT (two-pod) deployment boundary, and it demonstrates idempotent receipts and never-raise envelopes. The Magentic POC can reuse this boundary and only add an OSI-8 semantic adapter as a non-conflicting layer. [3]

4) Profile 1 and Profile 2 CPCP repos (PS1-P1, PS1-P2)
- Profile 1 demonstrates the Cyborg Channel with CID linkage and a two-pod topology; Profile 2 demonstrates reference-passing with bounded previews and on-demand dereference. These profiles anchor the minimal POC path for read/write semantics and cross-pod invocation. [4] [5]

5) NOOA harness and Switchyard
- NOOA provides a programmable harness with typed I/O, pass-by-reference semantics, code-as-action, programmable loop, explicit object state, and model-callable harness APIs. Switchyard is a routing proxy for LLM traffic and can be used to select model providers or route calls via a CPCP-adapted boundary. The combination supports the agentic loop and routing for the Magentic POC. [7] [6] [8]

6) Active Record as Context/Memory store
- Active Record is Rails’ ORM/persistence layer; for the Magentic POC it serves as the Context and Memory store with immutable ledger-like entries for provenance and outcome tracking. It is not a replacement for graph or event-sourced semantics; those must be layered where needed. [9]

5 seam-level assessment (high-level risks and mitigations)
- Seam 1: OSI Level 8 vs CPCP layering: The architecture is coherent if OSI-8 defines the semantic grammar while CPCP provides the pod packaging and contract surface. Risk: duplicated shapes across repositories and potential drift. Mitigation: pin a single profile revision per POC, use a canonical CID, and keep OSI-8 as the semantic layer atop CPCP. [1] [2]
- Seam 2: Rails-OSI-8 vs rails-cpcp ownership: rails-cpcp remains the public transport and contract layer; rails-osi-level-8 acts as a semantic adapter, not a competing surface. Ownership boundaries should be explicit to avoid two RPC surfaces. [3]
- Seam 3: AR as Context/Memory vs log/ledger semantics: AR is suitable for the POC’s durable projections and receipts but does not by itself guarantee a graph/event-log truth. The honest trade-off is to keep AR for transactional state while layering an immutable ledger subset for canonical Context/Memory. [9] [2]
- Seam 4: NOOA harness boundary and surface mapping: Harness must live outside the Rails process and be accessed via a CPCP adapter that maps OSI-8 Effects to model calls through Switchyard. This preserves isolation and explicit CPCP boundaries. [7] [6] [8]
- Seam 5: Four-container pod topology vs minimal POC scope: The public CPCP examples show FRONT/BACK, but a four-container interpretation is a local POC decision. If four containers are required for conformance, they should be defined in the CID and CID-enabled profile rather than assumed as a fixed architectural rule. [2] [4] [5]

Open questions to resolve in a build phase
- Which exact profile revisions and CID digests define the POC contract? Which CPCP profile P{N} is in scope for the minimal PoC (likely P1 and P2 as seeds)? [4] [5]
- What is the authoritative four-container topology for the Magentic POC if we treat it as a four-role pod? How is it reflected in the CID and the CPCP surface? [2]
- How should pass-by-reference be surfaced across pod boundaries? Is it a capability reference, a bounded preview, or a dereference operation? [5]
- Which specific Effect class is safe for the first durable write, and what is the required human checkpoint? [3]
- What constitutes a single, unequivocal success signal for the POC (Profiles 1–3)? [4] [5]

Preliminary architecture outline (textual layered description)
- Layer 1: Interface semantics (OSI Level 8) – Provided by a new Rails engine rails-osi-level-8. It exposes the semantic Cyborg Channel grammar through a constrained JSON-RPC-LD surface, with SHACL governance and three-ledger model guidance (canonical / sync_intent / private_local) on the read/write semantics. This layer acts as the Cyborg-facing facade, ensuring Context reads and Effects adhere to the profile constraints. It relies on the CPCP contracts for surface semantics, not on a separate RPC surface. This layer is designed to be mounted within the Rails app and to interact with the CPCP layer through well-defined adapters. [1] [2]
- Layer 2: Pod contract surface (CPCP) – Provided by rails-cpcp. This surface exposes /_cpcp, with CID-based JSON-RPC-LD envelopes, never-raise envelopes, and idempotent operation handling. The FRONT and BACK images are wired through a two-pod deployment pattern (FRONT reads a CID, BACK stores and validates; the Magentic POC leverages this as the canonical contract boundary). The four-container interpretation (BACK, FRONT, model gateway/cpcp adapter, and routing surface) is a local interpretation for the Magentic POC. [3]
- Layer 3: Context/Memory layer (Active Record) – ActiveRecord provides the durable store for Context projections, Memory, and provenance/outcome records. It maps to canonical projections and bounded views used by OSI-8 semantics and CPCP envelope validation. It supports immutability of core ledger entries for auditability while allowing transient NOOA state to exist outside the persistent store. [9]
- Layer 4: Agentic harness boundary (NOOA) – The NOOA harness runs in a Python runtime outside the Rails process, consuming Context via the CPCP adapter, performing the programmable loop, and invoking model calls through a CPCP-facing adapter. This boundary enforces isolation and explicit model-call semantics and surfaces results back through the CPCP channel. Switchyard optionally routes the model invocation to a specific provider behind the CPCP contract. [7] [6] [8]
- Layer 5: Model routing boundary (Switchyard) – Switchyard provides a routing surface to select model providers and translate between OpenAI/Anthropic-like interfaces and the selected backend. The hosted Switchyard surface (switchyard.online) offers a single CPCP route surface; for the Magentic POC, routing decisions are driven by CPCP-backed adapter logic rather than embedding inference logic in the router itself. The router exposes a destination decision and provenance context but not raw model outputs. [6] [8]
- Layer 6: Model gateway adapter – A CPCP-adapted boundary that invokes the actual model through the chosen provider (via Switchyard or a local integration) and returns a bounded, interpretable result to the harness. This ensures a single model-call path behind the CPCP contract. [5] [8]
- Layer 7: Deployment and orchestration – Minimal deployment would include Rails BACK (app with rails-cpcp/rails-osi-level-8), a separate Python NOOA FRONT harness, and a Switchyard component (either hosted or embedded). If a four-container pod is required for conformance, the model gateway and Switchyard surface would be included as distinct layers, but the public contract would still be the CPCP surface. [3] [8]
- Layer 8: Profiles mapping and governance – A mapping from OSI Level 8 profiles (1–8) to the minimal POC surface (P1, P2, and P3 subset) with a staged approach to Profile 4–8 durability and provenance. This ensures a controlled, incremental expansion of capabilities without drifting from the single-signature contract and single source-of-truth CID lineage. [1] [2]

Representative end-to-end flow for one representative agentic operation (minimal POC scope)
- Step 1: The Cyborg Human initiates a bounded Cyborg task and authorizes the Context view to be pulled. OSI Level 8 semantics are used to frame the Context request under the CID’s constraints. [1]
- Step 2: The Rails BACK stores a durable Context projection in Active Record and returns a bounded preview to the NOOA harness via a CPCP PULL path. The OSI-8 boundary ensures only permitted Context views are exposed. [9] [5]
- Step 3: The NOOA harness runs its programmable loop, using typed inputs and a bounded preview, and issues a model-call via the CPCP adapter. The harness uses pass-by-reference semantics to reference a live object or a capability handle. [7]
- Step 4: Switchyard routes the model invocation to the selected provider, returning the result in a CPCP-compatible envelope. The adapter then bridges the Switchyard result to a bounded, visible output to the harness. [6] [8]
- Step 5: The harness emits a non-destructive Insight (PUSH) back into CPCP, which the Rails BACK validates; a durable receipt is written, and a minimal provenance/outcome chain is stored in Active Record. The human may review the outcome if required by policy. [3] [4]
- Step 6: The system logs one lightweight outcome and stores a trace in the ledger, capturing the minimal provenance for auditability. [9]

Minimal POC boundary (architecture guidance only)
- Build a three-node logical deployment: Rails BACK (Rails app with rails-cpcp + rails-osi-level-8), Python NOOA FRONT, and a routing boundary to Switchyard (hosted or local). If four containers are mandated for conformance, include a dedicated model gateway/CPCP adapter and a local Switchyard instance as separate pods. The minimal proof proves the vertical slice: one bounded Context read, one bounded model invocation, one non-destructive Insight, and one durable receipt/trace.

Key open questions for the build phase
- What is the exact authoritative Profile revision/digest to pin for the POC? Which Profile(s) will be demonstrated (likely P1 and P2) and what is the minimum that must be proven for profiles 4–8? [4] [5]
- Is a four-container pod topology a mandatory CPCP conformance rule for the Magentic POC, or is it a local interpretation? If needed, how is that reflected in the CID and the registry? [2]
- How should cross-language pass-by-reference be surfaced at the CPCP boundary? What is the precise mapping from NOOA’s runtime references to CPCP capability handles? [6] [7] [8]
- Which single, safe, durable output should be proven first (one non-destructive Insight, one receipt)? What is the minimal human gate for a first durable push? [3]
- How will provenance and biography be recorded for the minimal POC, and what is the baseline requirement for Profile 5–8 later expansion? [2] [9]

References (public repositories and documentation used to ground the assessment)
- OSI Level 8 public repo: laquereric/osi-level-8. https://github.com/laquereric/osi-level-8
- CPCP / JSON-RPC-LD-PS1 base and Profile 1/2 context: laquereric/cyborg-pod-contract-package; laquereric/JSON-RPC-LD-PS1-P1; laquereric/JSON-RPC-LD-PS1-P2. https://github.com/laquereric/cyborg-pod-contract-package, https://github.com/laquereric/JSON-RPC-LD-PS1-P1, https://github.com/laquereric/JSON-RPC-LD-PS1-P2
- rails-cpcp (Rails engine for CPCP): https://github.com/laquereric/cpcp
- Profile 1 CPCP: https://github.com/laquereric/JSON-RPC-LD-PS1-P1
- Profile 2 CPCP: https://github.com/laquereric/JSON-RPC-LD-PS1-P2
- NOOA harness: https://github.com/NVIDIA-NeMo/labs-OO-Agents
- Switchyard routing: https://github.com/NVIDIA-NeMo/Switchyard, https://switchyard.online
- Profile 3 base, OSI-8 surface (for context on layering): https://github.com/laquereric/osi-level-8
- Rails Active Record docs: https://guides.rubyonrails.org/active_record_basics.html

Notes
- The Magentic POC document intentionally avoids implementation detail and full schemas; it focuses on the orchestration between the OSI Level 8 semantic layer, CPCP contract layer, Rails AR as durable store, and the NOOA harness with Switchyard routing. The final design should pin a concrete CID/digest, confirm four-container topology if required, and establish explicit boundary contracts between Rails, NOOA, and Switchyard before any code is written.

References:
[1] laquereric/osi-level-8 — OSI Level 8: A Cybernetic Interface, JSON-RPC-LD, SHACL, Profiles
[2] cyborg-pod-contract-package — PubSubStandard_1 (JSON-RPC-LD-PS1): CPCP standard + registry
[3] rails-cpcp — Rails engine: mounting CPCP pod at /_cpcp and two-pod deployment
[4] JSON-RPC-LD-PS1-P1 — Profile 1 Cyborg Channel CPCP
[5] JSON-RPC-LD-PS1-P2 — Profile 2 Reference-Passing CPCP
[6] NVIDIA-NeMo/labs-OO-Agents — NOOA harness architecture
[7] NVIDIA-NeMo/Switchyard — LLM routing proxy
[8] switchyard.online — hosted CPCP route surface
[9] Rails Active Record Basics — ORM and persistence semantics

Title: Magentic POC — Feasibility Assessment and Preliminary Architecture

This document is derived from public references and the plan to deliver a minimal, vertically scoped PoC that demonstrates OSI Level 8 semantics integrated with CPCP, Rails AR, NOOA, and Switchyard. The boundary conditions, ownership, and instrumented flow are designed to avoid over-commitment to full Profiles 4–8 while establishing a coherent integration model for the Magentic POC.