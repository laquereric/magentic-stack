# threedot-vscode Journey Wizard Design Memo

**Author:** Manus AI  
**Scope:** threedot-vscode v0.0.5 and the supplied Rails and JavaScript developer storyboards  
**Decision:** Make the `...` extension a CID-grounded process guide, rather than a generic, unconstrained editor wizard.

## Executive summary

This design memo defines a guided, CID-grounded journey inside VS Code for two developer personas, mapping every storyboard step (Rails and JavaScript) to concrete threedot-vscode plugin affordances. It prescribes a single hybrid wizard: a native Walkthrough entry point to initiate and resume the journey, plus a persistent Journey webview as the authoritative process surface that renders state-sensitive content, gates actions with CID binding and mmg-scape discovery, and orchestrates deployment and verification tasks via native VS Code Task API. The approach reuses existing threedot-vscode affordances (completion, embedCID, CodeLens, diagnostics, CID tree) where applicable and introduces targeted new commands, views, and tasks to drive the six-step journey for each persona. Walkthroughs provide onboarding structure; the webview provides a stateful, graph-like surface for decision points, evidence, and gatekeeping. This arrangement aligns with the VS Code UX guidance on guided onboarding and telegraphs the process state through altitude, CID provenance, and ground truth for every step.

Walkthroughs are explicitly designed to onboard users in multiple steps [Walkthroughs], while webviews enable rich, custom UIs for stateful processes [Webview]. The design relies on VS Code when/clauses for gating and on TreeView/CodeActions for in-context operations, ensuring decisions stay grounded in CID/PCP evidence and never-raise envelopes. See references for guidance on contributions, when-clauses, and tree views [Walkthroughs] [Webview] [When Clause Contexts] [Tree View API] [Contribution Points].

## 1) Storyboard-to-affordance map — Developer Rails (six steps)

Altitude and step mapping follow the Rails spine: from Integration (Mission) to explicit Operations (Experience), to Pod Boundary (Engineering), to Generate/Bind/Run (Code), to Qualify (Engineering), to Release (Mission). For each step, we map to a VS Code affordance (existing or new) and describe what threedot does and what completion/grounding evidence is produced.

| Step and altitude | VS Code affordance and command ID | What threedot does | Completion evidence and grounding |
|---|---|---|---|
| 1. Integration that cannot be a leap of faith — Mission | New command: threedot.journey.selectIntegration (Walkthrough-driven quick pick) | Capture integration objective, intended counterparty class, outcome, data direction (PULL/PUSH), data sensitivity, and expected proof; open an Integration Brief document and emit a CID evidence node in the CID tree | Integration intent persisted in .threedot/journey.json as integrationIntent; next step unlocked only when objective, direction, and evidence criteria are explicit |
| 2. From product flow to explicit operations — Experience | New command: threedot.journey.defineOperations (QuickPick/InputBox-backed) | Translate product flow into named operations with labels, direction, request/response shapes, and never-raise envelope definitions; render an Operation Plan document | CID-compatible operation manifest overlay validated against schemas; diagnostics show missing envelopes rather than optimistic success |
| 3. Draw the pod boundary — Engineering | New command: threedot.cpcp.planBoundary (pod boundary scaffold) | Propose a four-role CPCP boundary (FRONT, BACK, BackJob, GRAPH); generate a reviewable cpcp.pod.yaml; open a pod boundary view/virtual document | Pod boundary captured with roles and edges; graph/pod boundary records; preflight checks ensure no in-process jobs | 
| 4. Generate, bind, and run the Rails pod — Code | Existing: completion provider on . and threedot.embedCID + threedot.insertCapability/insertOp; New: threedot.cpcp.generateBindRun to drive code generation and a Run Task | Generate the CPCP pod, bind the CID at /_cpcp/cid.json, bind code at the Rails call site via CID, and run the pod | Generated CID-bound code with an embedded CID reference; adapters and never-raise envelope in place; diagnostics extended for unknown capabilities |
| 5. Qualify before calling, observe without guessing — Engineering | New: threedot.mmgScape.discoverQualify + tree-based results + threedot.scape.openObservation | Discover/qualify candidates using mmg-scape; present qualified results in a TreeView; insert a qualified call with provenance | Discovery record and qualified candidate chosen with CID hash; provenance and freshness included; unqualified results blocked |
| 6. A release becomes a market-ready party — Mission | New: threedot.release.prepare + threedot.cpcp.verify + threedot.release.openEvidence | Aggregate mission intent, operation contracts, current CID, qualification, and verification; run deploy and verify tasks; expose an evidence document | Release readiness is derived from successful deploy and mmg-cpcp-verify report; if verification fails, the evidence document reflects failure and blocks release |

Grounding notes for Rails: the spine emphasizes a single spine of executable steps with CID and CPCP grounding at the Code altitude, reinforced by ground-truth evidence at each gate. The generated artifacts include the CID descriptor, pod boundary YAML, and verification reports. The design ensures never-raise envelopes drive runtime behavior and that the operator never assumes a working integration without CID-verified bindings and qualification evidence. The Rails path provides the strongest shared backbone for the JavaScript path to reuse.

## 2) Storyboard-to-affordance map — Developer JavaScript (six steps)

The JavaScript path mirrors Rails but emphasizes interface contracts and front-door composition. It reuses the same CID, discovery, envelope, and verification mechanics, but with persona-specific prompts and surface checks.

| Step and altitude | VS Code affordance and command ID | What threedot does | Completion evidence and grounding |
|---|---|---|---|
| 1. The interface carries a promise — Mission | New: threedot.journey.defineInterfacePromise | Capture the interface promise, owner/action, eligibility, and discovery/disclosure parameters; create an Interface Promise document | Promise documented in journey state; no service bound until CID-binding occurs |
| 2. Put a calm front door on a serious contract — Experience | New: threedot.frontdoor.scaffold + threedot.frontdoor.preview | Establish a front door state machine: idle, discovering, qualified, unavailable, pending, envelope-return, resolved; render a preview | Front-door state machine documented; never-raise envelope visible as part of UI state |
| 3. Bind the experience to what is actually possible — Engineering | threedot.contract.bindCapabilities + threedot.contract.openBindingMatrix | Enforce CID-bound capabilities mapping, ensure that available actions match the CID operation, bind at cursor if needed | Binding matrix resolves to concrete CID operation IDs; diagnostics warn on unknown shapes or missing envelopes |
| 4. Compose the interaction, let the contract travel — Code | Existing: completion/provider on . and threedot.embedCID; new: threedot.frontdoor.composeInteraction | Generate code templates bound to CID operations; embed CID descriptor into code; provide envelope-ready scaffolding | Code contains embedded CID hash; envelope handling logic present; CodeLens/hover reflect CID binding |
| 5. Discover before you offer a choice — Engineering | threedot.scape.discoverChoices + threedot.scape.populateChoice + mmg-scape results | Query mmg-scape for eligible candidates; display qualified results with provenance; avoid unqualified options | Discovery records with candidate provenance and CID hash; qualified choice available for binding |
| 6. The front end becomes a trusted commerce surface — Experience | threedot.frontdoor.verifySurface + threedot.release.openEvidence | Validate interface-to-CID binding, enforce qualified choices, emit release surface evidence or verification results | Surface Evidence document includes contract verification, qualified decision provenance, and deployment/verification status |

JavaScript similarly reuses the Rails backbone but emphasizes the front-door and interface promise surfaces, ensuring all decisions are CID-grounded and that the same gatekeeping rules apply to both paths. The front door’s trust model ensures that the UI never represents commerce readiness without proof of binding, qualification, and verification.

## 3) Recommended wizard shape and state model

UX recommendation: a single hybrid wizard with a native Walkthrough as the entry point and a persistent Journey webview as the authoritative process surface. The Walkthrough handles orientation, persona selection, and resume/restart; the journey webview shows the six-step process, altitude, and per-step gating. Small decisions should be handled via QuickPick/InputBox, while more complex steps (pod boundary, binding, discovery) use dedicated webview panels or in-editor UI primitives (TreeView, CodeActions). This approach aligns with VS Code guidance on Walkthroughs and Webviews: use a guided, multi-step experience for onboarding, while keeping complex process state in a dedicated, stateful surface [Walkthroughs] [Webview Guidelines]. The state model is stored in a durable journey file (.threedot/journey.json) and mirrored in a transient workspace cache for fast restoration.

Proposed state model (key fields):

| State field | Purpose | Example |
|---|---|---|
| schemaVersion, journeyId, persona | Durable identity and migration | 1, rails-orders, rails |
| currentStep, currentAltitude, status | Current presentation state | rails.4, code, blocked |
| intent or interfacePromise | Mission decision, including PULL/PUSH | { direction: "PULL", ... } |
| operations[] | Experience actions and CID operation contracts | { placeOrder -> commerce.order.place@v1 } |
| artifactRefs | URIs/hashes of CID, pod specs, generated files | { cid: { uri, sha256, ... } } |
| qualification[] | mmg-scape query results and verdicts | { qualified: true, expiresAt: ... } |
| taskRuns[] | Tasks (generate/bind/run/deploy/verify) and outputs | { name: "cpcp.run", exitCode: 0, reportUri: "..." } |
| stepChecks | Derived gating statuses | { podBoundaryPassed: true, inProcessJobs: false } |
| provenance | Correlation IDs and history | { cidHash: "...", releaseId: "..." } |

State management is centralized in a JourneyStateService that recalculates gate conditions on event occurrences (CID reload, task completion, discovery update, etc.). Downstream steps must be invalidated if evidence changes (e.g., CID hash changes after code binding) rather than silently proceeding.

Unlocking and gating rules use VS Code context keys to drive enablement and visibility. Examples include threedot.journey.active, threedot.journey.persona, threedot.journey.step, threedot.journey.altitude, threedot.canAdvance, threedot.cid.valid, threedot.scape.qualified, and threedot.verify.passed. The status bar can surface a compact altitude breadcrumb and focus the Journey panel when clicked; the CID tree receives Journey-grouped nodes for Journey, Evidence, Discovery, and Release Evidence.

## 4) Concrete threedot-vscode additions

To realize the journey as described, the extension must introduce a defined set of new commands, Contribution Points, and runtime providers, while reusing and extending the existing affordances where possible.

### Command surface (new commands)

- Journey control: threedot.journey.start, threedot.journey.resume, threedot.journey.selectPersona, threedot.journey.selectIntegration, threedot.journey.defineInterfacePromise, threedot.journey.defineOperations, threedot.journey.openEvidence
- CID and experience binding: threedot.contract.bindCapabilities, threedot.contract.bindAtCursor, threedot.contract.openBindingMatrix
- Rails/CPCP pod: threedot.cpcp.planBoundary, threedot.cpcp.generateBindRun, threedot.cpcp.run, threedot.cpcp.deploy, threedot.cpcp.verify
- JavaScript front door: threedot.frontdoor.scaffold, threedot.frontdoor.preview, threedot.frontdoor.composeInteraction, threedot.frontdoor.verifySurface
- mmg-scape discovery: threedot.scape.discoverQualify, threedot.scape.discoverChoices, threedot.scape.qualifyChoice, threedot.scape.insertQualifiedCall, threedot.scape.populateChoice, threedot.scape.openObservation
- Release proof: threedot.release.prepare, threedot.release.publishSurface, threedot.release.openEvidence

These commands are designed to be composable and invoked from the panel, the CID tree, or the command palette. They map to small, reusable actions rather than monolithic wizard steps.

### Contributions and providers (new points or extensions)

- conributes.walkthroughs: one walkthrough threedot.getStartedJourney to initialize a journey and resume later
- conributes.commands: the journey, pod, discovery, and release commands listed above
- conributes.menus: view/title for journey resume/refresh; view/item/context for CID capability, journey step, candidate, and evidence nodes; editor/context for bind-at-cursor and compose interaction
- conributes.views and threedotCaps: extend CID view with Journey, Capabilities, Pod, Discovery, and Release Evidence groups
- conributes.viewsWelcome: provide a Start a 3dot Journey link when no journey exists
- conributes.taskDefinitions and TaskProvider: define task types cpcp.run, cpcp.deploy, cpcp.verify, and frontdoor.verify
- conributes.codeActions: Bind to CID operation, Embed selected CID, Insert qualified call, Generate envelope branch, Refresh stale discovery
- conributes.configuration: expose journey and CPCP endpoints, freshness windows, and verification profiles
- Runtime providers: provide JourneyPanelProvider, JourneyTreeDataProvider, JourneyStateService, EvidenceDocumentProvider, CpcpTaskProvider, MmgScapeClient, JourneyCodeActionProvider, JourneyDiagnosticBridge

The extension will leverage existing affordances (CID completions, embedCID, hover, CodeLens, diagnostics, status bar, CID tree) and augment them with journey-specific gating and evidence flow. The manifest should preserve current CID-related experiences and avoid duplicating UI surfaces.

### Grounding plan and gating primitives

- CID-bound code: code completions and insertions must retain CID references; a CID change invalidates prior bindings until revalidated
- PULL/PUSH: operation records specify direction; the composer derives flow from this envelope
- Never-raise: adapters expose an envelope type; the UI must cover all envelope states via diagnostics rather than real exceptions in user code
- mmg-scape qualification: discovery results include criteria, freshness, and CID hash; only qualified candidates enable callable actions
- CPCP deploy/verify: Task results produce machine-readable reports; the verifier ensures required four roles, no in-process jobs, and a persisted graph before signaling release readiness

### Minimal end-to-end build sequence (Rails-first)

1) Define the journey state schemas and deterministic fixtures for journey.json, CID artifacts, mmg-scape results, and CPCP verify reports
2) Implement JourneyStateService, the Walkthrough entry, the Journey panel shell, and the top-level CID tree integration
3) Implement Rails steps 1–2 (intent and operation plan) with integration brief and operation plan artifacts
4) Implement Rails step 3 (pod boundary) and static preflight checks
5) Wire Rails step 4 (generate/bind/run) to existing completion and embedCID pathways; ensure CID.json binding exists
6) Implement Rails step 5 (discovery/qualification) and its CodeActions for qualified calls
7) Implement Rails step 6 (deploy/verify) and the Release Evidence surface with tasks
8) Implement JavaScript adapters on top of the shared process engine, reuse steps 1–6 with persona-specific front-door prompts
9) Harden with trust guards, SecretStorage for credentials, cancellation/retry semantics, accessibility improvements, and telemetry appropriate for CID data

The Rails path provides the spine for shared process engine reuse by the JavaScript path and ensures a single, coherent journey surface for both personas.

## 4) Build sequence and governance

- Phase 1: Implement the Journey surface, the Walkthrough entry, and the Journey state management; create the journey.json structure and the initial CID-tree scaffolding
- Phase 2: Implement the Rails steps with integration/manual proof gates and the pod boundary scaffolding; add the embedCID/binding logic for code altitude
- Phase 3: Implement the mmg-scape discovery and binding, plus qualified results gating and evidence generation
- Phase 4: Implement CPCP deploy/verify tasks and the Release Evidence surface; integrate with TaskProvider and the Build/Run/Deploy flows
- Phase 5: Implement the JavaScript surface atop the shared engine, focusing on Interface Promise, Front Door scaffolding, and front-door verification
- Phase 6: Harden the system with workspace trust, SecretStorage usage, cancellation, accessibility, and telemetry, and validate a complete Rails-first vertical slice before enabling the JavaScript path
- Phase 7: Validate UX with the Walkthrough and the Journey webview in concert, ensuring gating and grounding remain intact through reloads and workspace changes

## 5) Decision summary

The threedot-vscode journey-wizard is a CID-grounded process controller embedded in VS Code. It uses a hybrid approach: a native Walkthrough for orientation and resume, and a single Journey webview as the authoritative process surface for decision gates, CID grounding, and evidence. The extension composes with existing CID capabilities and adds new journey-specific commands, contribution points, and task-based lifecycles to realize a Rust-like, gate-driven workflow that remains grounded at every altitude (Mission → Experience → Engineering → Code). This design aligns with the VS Code UX guidelines on guided onboarding and the Walkthroughs/Webviews guidance, while preserving the ability to access and run any step directly from commands or the CID tree when needed.

## References

[1] https://code.visualstudio.com/api/ux-guidelines/walkthroughs  Walkthroughs – Visual Studio Code Extension API

[2] https://code.visualstudio.com/api/extension-guides/webview  Webview API – Extension Guides

[3] https://code.visualstudio.com/api/references/when-clause-contexts  When Clause Contexts – VS Code API

[4] https://code.visualstudio.com/api/extension-guides/tree-view  Tree View API – Extension Guides

[5] https://code.visualstudio.com/api/references/contribution-points  Contribution Points – VS Code API

---

**Source boundary:** All product-specific CID, CPCP, mmg-scape, PULL/PUSH, never-raise, and storyboard facts in this memo are reasoned from the user-supplied context. External references are bounded by the VS Code documentation cited above.