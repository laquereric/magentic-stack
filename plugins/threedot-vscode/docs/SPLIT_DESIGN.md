<!--
Preliminary split design drafted by the Manus cloud agent (task NBvhVuSB9HDQPsDHqhyPUQ), 2026-08-18. Review-ready; not independently verified.
-->

# Preliminary Design: Split threedot-vscode into a Webview Shell (FRONT) and Rails CPCP BACK

Status: Preliminary architecture (architecture-only, no implementation details). All design decisions herein are scoped to the separation of concerns, data ownership, and the CPCP transport seam; no live data or code is included.

Executive summary
- The current threedot-vscode extension reads a STATIC CID from .threedot/cid.json and exposes language features derived from that static descriptor. The target architecture replaces this single-file authority with a two-component CPCP-based split: a thin React/WebView-based front-end shell inside VS Code and a Rails-based back-end that serves CID data, operations, and the plugin object model via the CPCP seam. The public contract seam remains the CPCP endpoint at /_cpcp.
- The static cid.json file becomes a bootstrap seed used only to reconnect to the live CPCP back-end. The CID root, operations, and object model live in Rails ActiveRecord, not in the static workspace. The webview shell consumes a live Context/Operation graph from the back-end via the CPCP PULL/PUSH model.
- The architecture aligns with CPCP standards and OSI Level 8 concepts, grounding the back-end in the ActiveRecord CID-rooted model and deferring RDF projection to a later phase.

Rationale and references: CPCP and OSI Level 8 concepts are documented in the Cyborg Pod Contract Package standard and related repositories, including the CPCP seam and PULL/PUSH semantics. See the references at the end for source material. [1] [2] [3] [4] [5] [6] [7]

1) System architecture overview
- FRONT (threedot shell): a WebView-based presentation layer inside VS Code. It renders the “ellipsis front door,” Develop/RUN tabs, journey, and capabilities, but it holds no authoritative data. It communicates with the BACK exclusively through the CPCP seam (GET /_cpcp/cid.json for discovery, POST /_cpcp/rpc for PULL/PUSH operations). The shell maintains transient UI state and a digest-tagged cache of the live Context for responsiveness. The front-end does not mutate live CID data.
- BACK (rails-threedot-back + rails-cpcp): the Rails engine provides the live data plane. It serves the live CID(s), operations, and the plugin object model as ActiveRecord records rooted at CID. It composes with rails-cpcp to expose a single public seam at /_cpcp. The back-end is authoritative for all Context, Operations, Capabilities, Shapes, and object-model state. The optional rails-osi-level-8 component can be layered onto BACK (grounding/evidence) but is not required in the first cut. See the CPCP seam documentation for /_cpcp and the OSCI-level-8 grounding concepts. [3] [6] [7]
- Seams and data flow: The bootstrap cid.json seed is used only for discovery; the live contract is obtained via GET /_cpcp/cid.json. PULL flows read Context from the domain CID; PUSH flows carry typed Effects back to the BACK for validation and receipt generation. The shell renders the results and provides language features derived from the live CID projection. [4] [5]

2) CID-rooted model and CPCP interaction flows
- CID as the query root: In Rails, CID is the root ActiveRecord, with associations to Operations, Capabilities, Shapes, and ObjectNodes. The CID exposes the operation manifest and SHACL-constrained shapes; the shell derives its UI model (parameters, required fields, and result shapes) from the live projection rather than static cid.json. This preserves the AR-first design for the live data surface while enabling the webview to render capabilities and editor features. The live contract is accessed through the single public seam at /_cpcp. [3] [4]
- CPCP PULL: The shell uses PULL to read Context from the BACK via the domain CID. The back returns a representation of the Context and linked CID references. The shell then maps Context into UI state and VS Code language features. [4] [7]
- CPCP PUSH: The shell issues a PUSH for a typed closed Shape (Note) referencing the domain CID. The BACK validates the operation, enforces idempotency (operationId), and returns a receipt envelope. All authorization, validation, and persistence occur on the BACK side. [4] [3]

3) Bootstrap, bootstrap fallback, and discovery flow
- bootstrap seed: The existing .threedot/cid.json remains as a bootstrap seed only. It must not carry live operational data. Its role is to bootstrap CPCP path discovery (where is the back, what is the _cpcp seam). The BACK updates the live CID projection after connection. If the back is unavailable, the shell presents a disconnected state with retry semantics; no live operations are performed from the seed. This ensures a strict boundary between the seed and live data. [2] [3]
- live discovery: On successful bootstrap, the shell fetches the live service CID via GET /_cpcp/cid.json and then uses PULL to populate the UI with the domain CID’s Context/Operations. The seed only aids initial bootstrap; subsequent operation lives in Rails AR. [3] [4]

4) Rails composition and CPCP seam integration
- rails-cpcp: The Rails extension provides a single public seam at /_cpcp and the envelope semantics (PULL/PUSH, never-raise envelopes, liveness) and the JSON-RPC-LD integration. It remains the public contract surface and does not introduce a new endpoint family beyond the seam. The README describes mounting at /_cpcp and exposing cid.json and rpc endpoints. [3]
- rails-threedot-back: A new Rails engine that expresses the CID-rooted AR domain, including live CIDs, operations, object model, and domain authorization/validation logic. It consumes the CPCP contract delivered by rails-cpcp and never creates a separate REST/RPC surface. [4]
- rails-osi-level-8 (optional): If enabled, decorates the BACK with semantic grounding (three-ledger discipline: canonical, sync_intent, private_local) and profile evidence; this is additive and not mandatory for the first cut. It remains behind the CPCP seam. [6] [7]

5) Initial RDF projection (Storable) and deferred work
- Vv::Graph::Storable may be enabled on the AR models as an RDF projection facility, but it is deferred to a later phase. The first cut remains AR-primary; RDF projection can be introduced as a post-MVP enhancement. This keeps the operational surface simple and aligned with the operator constraint that RDF projection is optional in early iterations. [6]

6) First-cut delivery sequence (high-level plan)
- Phase 1 (completed): Inspect requirements and gather authoritative CPCP/OSI Level 8 materials. [4] [7]
- Phase 2 (current): Define boundary, CID-rooted model, and CPCP interaction flows (this document).
- Phase 3 (upcoming): Specify bootstrap, composition, deferred RDF projection, and first-cut delivery sequence (the steps outlined here). [3] [4]
- Phase 4 (upcoming): Deliver the final preliminary architecture design with sources. [1] [2]

7) First-cut build and proof steps (minimal scope)
- Boot the shell front-end inside VS Code as a webview-based UI with a small extension-host bridge that acts as a CPCP client. No live CID data is stored on the shell. [1] [3]
- Introduce rails-threedot-back and mount rails-cpcp at /_cpcp with a single live CID as the initial query root. Expose one domain CID and its basic Context/Operations. Validate that the CPCP path can PULL and PUSH end-to-end from shell to back. [3] [4]
- Validate bootstrap seed behavior: the seed is used only for path discovery, not for live operations; on reconnect, the live domain CID is pulled from /_cpcp/cid.json. [2] [3]
- Demonstrate a successful PUSH, with the server returning a receipt envelope and maintaining idempotency through operationId. [3] 

8) Architecture diagram and diagram reference
- The boundary and data-flow diagram illustrating the shell-to-back CPCP boundary is provided as a diagram (Mermaid/Markdown) and rendered as an image for inclusion in the final report. See the architectural diagram image included with the deliverable. Figure: threedot_split_architecture.png. [4]

9) Deliverables
- A single archive containing the final Preliminary Design document plus the architecture diagram (the current deliverable). The archive previously generated includes PRELIMINARY_DESIGN.md and threedot_split_architecture.png. See the attached deliverable package. [4]

10) References
- threedot-vscode repository and CID schema, showing current static CID usage and the seed-based bootstrap approach. [1] [2]
- rails-cpcp: the public CPCP seam at /_cpcp and the surface of cid.json + rpc. [3]
- Cyborg Pod Contract Package (CPCP) standard and seam. [4]
- Profile 1 CPCP material (Cyborg Channel) and the PULL/PUSH model. [5]
- OSI Level 8 and the groundings/evidence layering (optional). [6] [7]
- Additional context: the OSI Level 8 grounding approach and the three-ledger discipline. [7]

References
- [1] https://github.com/laquereric/threedot-vscode "threedot-vscode — 3dot Cyborg Interface for VS Code"
- [2] https://github.com/laquereric/threedot-vscode/blob/main/schema/cid.schema.json "threedot-vscode CID schema"
- [3] https://github.com/laquereric/cpcp/blob/main/README.md "rails-cpcp README"
- [4] https://github.com/laquereric/cyborg-pod-contract-package "Cyborg Pod Contract Package / JSON-RPC-LD-PS1"
- [5] https://github.com/laquereric/JSON-RPC-LD-PS1-P1 "Profile 1 — Cyborg Channel CPCP"
- [6] https://github.com/laquereric/rails-osi-level-8 "rails-osi-level-8 README"
- [7] https://github.com/laquereric/osi-level-8 "OSI Level 8 — Cybernetic Interface"