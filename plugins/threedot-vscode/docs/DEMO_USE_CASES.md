---
title: "3dot CPCP Use-Case Catalog and Demo Artifact"
source: manus
manus_task_url: https://manus.im/app/mKFQoqPf92kuRkJtnmQ9DT
note: Authored by the Manus cloud agent; demo use-cases, not independently verified.
---

# 3dot CPCP Webview for Rails Resources: Concrete Developer-and-Agent Use Cases

**Author:** Manus AI  
**Scope:** `magentic-stack`, the `threedot` VS Code extension, the supplied mind-pod BACK/FRONT/BACKJOB setup, and only the CPCP operations named in the BASE scenario.

## Grounding and scope
This document is anchored in the BASE scenario you provided. The BACK is a Rails 8 app that mounts rails-cpcp and exposes the `_cpcp` JSON-RPC-LD seam; FRONT is a DBless Rails browser shell; BACKJOB reconciles asynchronously; MIND is optional cognition. The 3dot extension discovers the live CID from GET <back>/_cpcp/cid.json, seeds a local `.threedot/cid.json`, and exposes the CPCP surface to both human and AI agent with no live mutation of the authority CID. Every operation is validated against the closed SHACL shapes declared in the CID, and governance evidence is surfaced via the OSI Level 8 projections.

> Cyborg: the human developer and the in-editor AI agent share the same CID-derived surface and work within the same governance and closure rules.

The deliverable artifact set below ground all usage in the exact named operations and the exact flow described in BASE. If the live CID changes or additional required properties are exposed, the demo code and catalog are designed to reflect those changes without inventing new capabilities beyond what the CID declares.

## Proposed exact demo artifact contents
### examples/vscode/threedot_demo.py (exact contents)
```python
"""3dot CPCP Rails navigation demo.

Open this file after the threedot extension has discovered the running BACK CID.
Use `three.` completions, F12 on a call to inspect its closed input shape, and the
3dot Activity view to see whether each operation is context, effect, or governance.

Do not add guessed keys to a CPCP payload. BACK's live CID is the contract, and
its closed SHACL shapes control what this editor surface will accept.
"""

import asyncio
import json

import three

# Reuse this value exactly to demonstrate an idempotent replay of the same effect.
OPERATION_ID = "threedot-demo-note-create-0001"


def show(label: str, value: object) -> None:
    """Keep results visible in the editor's terminal without assuming result shape."""
    print(f"\n--- {label} ---")
    print(json.dumps(value, indent=2, default=str))


async def main() -> None:
    # CONTEXT / PULL: type `three.` and accept the noteList completion.
    # Its call label should identify the operation as: 3dot · context → NoteList.
    note_references = await three.noteList()
    show("note.list returned references", note_references)

    # CONTEXT / PULL: dereference one value returned by note.list instead of
    # inventing an identifier. F12 on noteGet opens the operation in cid.json.
    if note_references:
        note_reference = note_references[0]
        note = await three.noteGet(note_reference)
        show("note.get dereferenced the first reference", note)
    else:
        print("No note reference is available to dereference in this BACK instance.")

    # CONTEXT / PULL: view the asynchronous reconciler's latest projection.
    reconciliation = await three.reconciliationLatest()
    show("reconciliation.latest", reconciliation)

    # EFFECT / PUSH: operationId is the one note.create field specified by the BASE.
    # If F12 shows further required fields in the *live* closed shape, accept the
    # completion-generated fields here; do not guess their names. Never add an
    # undeclared property: the editor will raise three/unexpected-param before call.
    note_create_input = {"operationId": OPERATION_ID}
    create_result = await three.noteCreate(note_create_input)
    show("first note.create result (never-raise)", create_result)

    # Replay the *identical* intent. BACK uses operationId for idempotency, so this
    # must not be treated as permission to create an unbounded second write.
    replay_result = await three.noteCreate(note_create_input)
    show("same-operationId note.create replay (never-raise)", replay_result)

    # GOVERNANCE / PULL: inspect the governed projection available from BACK.
    # The source of truth for canonical/sync_intent/private_local remains BACK.
    contexts = await three.l8ContextList()
    channels = await three.l8CyborgChannelList()
    journal = await three.l8OperationJournal()
    receipts = await three.l8ExecutionReceiptList()
    show("l8.context.list", contexts)
    show("l8.cyborg_channel.list", channels)
    show("l8.operation.journal", journal)
    show("l8.execution.receipt.list", receipts)

    # Diagnostic demonstrations — leave these commented. Un-comment one only to
    # see the local 3dot diagnostic before a CPCP request is issued:
    # await three.noteCreate({})
    #   ^ three/missing-required: operationId
    # await three.noteCreate({"operationId": OPERATION_ID, "notInCid": True})
    #   ^ three/unexpected-param: closed note.create shape rejects notInCid
    # await three.noteDoesNotExist()
    #   ^ three/unknown-capability


if __name__ == "__main__":
    asyncio.run(main())
```

The body intentionally makes no assumptions about result-envelope field names, note-reference encoding, or additional properties the live `note.create` shape may require. Its calls are the objects to navigate with the extension. Before executing the effect in a CID that declares additional required properties, the developer or agent uses completion/F12 to insert exactly those properties; the first attempted incomplete call will be stopped by `three/missing-required` rather than silently sent.

## 1) Numbered Use-Case Catalog (12–20 cases)

The catalog uses four roles: context (PULL/navigating), effect (PUSH/write), governance (OSI Level 8 evidence), and editor-only (diagnostics and CID exploration). Every case begins after BASE steps 0–4, unless specified otherwise. Each entry includes: id, title, actor, precondition, trigger, main flow (steps naming the 3dot affordances used), the CID operation(s) exercised and their ROLE, the never-raise / closed-shape / idempotency behavior surfaced, postcondition, and user value.

| ID | Title | Actor | Primary operation role | Precondition | Trigger | Main Flow (3dot affordances) | CID Operations Exercised (ROLE) | Guard / Validation Surfaces | Postcondition | User Value |
|---|---|---|---|---|---|---|---|---|---|---|
| UC-01 | Discover the authority CID from a running BACK | Both | Context (PULL) | BASE 0–3 complete; BACK reachable; no local CID seeded | Open webview or bootstrap discovery | 1) Open webview; 2) GET <back>/_cpcp/cid.json; 3) Seed .threedot/cid.json; 4) Observe status bar CID and Activity view | note.list? reconciliation.latest? l8 reads are governance-shaping but not invoked yet | Discovery is read-only; BACK remains authority | Editor affordances are calibrated to the live BACK CID | The editor can begin navigation from the declared seam |
| UC-02 | Start with a CID-derived completion | Human | Context (PULL) | UC-01 succeeded; threedot_demo.py open; CID loaded | Typing three. on noteList line | 1) Trigger language-native completion with three.; 2) Accept CID-derived noteList; 3) Import three auto-added; 4) Run code or trigger corresponding PULL | three.noteList (context/PULL) | Only CID-known operations appear; no mutation | note.list results available for dereference | A familiar Rails resource becomes discoverable via CID-driven surface |
| UC-03 | Navigate a listed note reference and dereference it | Human/Agent | Context (PULL) | UC-02 returned at least one note reference | Choose the first returned reference | 1) Read note_references from three.noteList(); 2) NoteGet on reference; 3) webview routes RPC; 4) Show resource | three.noteList, three.noteGet (context/PULL) | Reads are safe; no invented IDs; F12 reveals contract | The concrete resource is opened via a known BACK reference | Obtain a real resource from BACK without guessing IDs |
| UC-04 | Inspect the latest asynchronous reconciliation | Human | Context (PULL) | BACKJOB may be reconciling asynchronously | Trigger reconciliationLatest | 1) Complete reconciliationLatest; 2) Observe context label; 3) Compare with notes | three.reconciliationLatest (context/PULL) | Governance view surfaces; no mutation | The latest reconciliation is observed without mutation | See async state without mutating BACK |
| UC-05 | Use F12 to learn an operation's contract | Human | Editor-only (CID/BIN) and Context/Go to CID on-demand | CID loaded; cursor on a three.* call | F12 on a target call | 1) Go to CID (F12); 2) Inspect operation in cid.json; 3) Return to call and complete fields per shape | three.* operations; SHACL shapes at CID | On-demand contract discovery; shapes govern payloads | Onboarding within the editor; no external docs required |
| UC-06 | Separate read, write, and evidence capabilities | Human | Context / Governance / Editor-Only | CID loaded; Activity view present | Open Activity view and inspect groups | 1) Observe context (note.list, note.get, reconciliation.latest); 2) Observe effect (note.create); 3) Observe governance (l8.* reads) | note.list, note.get (context); note.create (effect); l8.* (governance) | Visibility of roles before dispatch | A role-based action plan; governance evidence is explicit |
| UC-07 | Stop an unknown capability before it becomes a request | Agent | Editor-only | CID loaded; agent editing demo | Probe for unknown capability | 1) Agent types a hypothesized noteSearch(); 2) Diagnostic three/unknown-capability surfaces; 3) Replace with valid sequence; 4) Proceed with declared operations | three/unknown-capability (diagnostic) | Unknown-capability is caught locally; no RPC made | Agent remains constrained by CID surface |
| UC-08 | Catch a closed-shape extra key before an effect | Human/Agent | Effect | note.create loaded; input shape is closed | Add extra key (notInCid) | 1) Complete with extra field; 2) Diagnostics catch three/unexpected-param; 3) Inspect CID shape via F12; 4) Remove extra key; 5) Invoke effect with operationId | note.create (effect/PUSH); three/unexpected-param (diagnostic) | SHACL validation blocks invalid keys before dispatch | Payload respects declared shape |
| UC-09 | Catch a missing required effect parameter | Human/Agent | Effect | note.create available in CID | Dispatch empty payload | 1) Attempt noteCreate({}); 2) Editor flags three/missing-required for operationId; 3) Add operationId; 4) Verify shapes; 5) Dispatch | note.create (effect/PUSH); three/missing-required (diagnostic) | Missing required keys blocked before dispatch | Ensure operationId is present and correct |
| UC-10 | Create a note through the sole writer | Human/Agent | Effect | UC-08/UC-09 clean; operationId present | Trigger push with operationId | 1) Confirm Activity view marks note.create as effect; 2) Confirm payload; 3) Push via webview; 4) BACK processes the effect | note.create (effect/PUSH) | BACK is the sole writer; never-raise result returned | The write is observable via governance after the fact |
| UC-11 | Replay an effect safely with the same operationId | Agent | Effect | UC-10 executed; same operationId used again | Re-run noteCreate with same operationId | 1) Push with same operationId; 2) BACK applies idempotent behavior; 3) Read governance evidence | note.create (effect/PUSH) with same operationId | Idempotent behavior observed; never-raise surface | Safe recovery that avoids duplicate writes |
| UC-12 | Audit the effect in the Level 8 journal and receipts | Human/Agent | Governance | UC-10/UC-11 executed; governance surface required | Open journal and receipts | 1) Command l8OperationJournal; 2) Command l8ExecutionReceiptList; 3) Compare with expected idempotent behavior | l8.operation.journal, l8.execution.receipt.list (governance reads) | Governance evidence available; external projection used | Auditable trace for the executed intent |
| UC-13 | Confirm the private-local boundary | Human | Governance | Governance surface opened; private_local boundary in BACK | Inspect governance outputs | 1) Open l8ContextList and l8CyborgChannelList; 2) Inspect closed shapes via F12; 3) Retrieve journal/receipts UC-12; 4) Confirm private_local boundary never exposed | l8.context.list, l8.cyborg_channel.list (governance) | Private_local never leaves BACK; bound by CID surface | Boundary confirmation and auditability |
| UC-14 | Let the AI agent use the identical CID surface | Agent/Human | All | Shared workspace; identical CID surface | Co-operate flows | 1) Agent inspects and uses same three.* calls; 2) Generates and uses a single operationId; 3) Executes push; 4) Governance readouts produced | All (context, effect, governance) | Identical surface ensures auditable, reviewable agent activity | Shared operational capability and auditability |
| UC-15 | Complete the six-step Cyborg Journey | Human/Agent | Journey | CID discovered; webview available | Open Cyborg Journey panel | 1) Mission; 2) Experience; 3) Engineering; 4) Code; 5) Evidence gates; 6) Deploy/verify/run-pod | All relevant operations across UC-02 to UC-14 | Each step requires evidence; no hidden shortcuts | End-to-end narrative of journey with proof |
| UC-16 | Hot-reload a changed local CID copy without mutating authority | Human | Editor-only | Local `.threedot/cid.json` present | Edit local CID; hot reload occurs | 1) Edit local CID; 2) Hot reload updates editor; 3) Use F12 or completion to confirm new shapes; 4) Rerun discovery against BACK | None required (metadata only) | Editor reflects change while BACK remains authoritative | Local iteration without mutating server CID |
| UC-17 | Work safely when BACK is disconnected | Human/Agent | Editor-only / Offline-ready | ONLINE discovery path unavailable; BACK RPC blocked | Attempt offline navigation | 1) Show failure in status bar; 2) Use local CID shapes to inspect; 3) Do not attempt direct MUTATE paths; 4) Re-discover when BACK returns | None (offline) | Editor remains usable for offline exploration; no writes attempted | Offline resilience and safe recovery |

> Note: The catalog intentionally includes 17 cases (UC-01 to UC-17) to cover discover, read, write, governance, diagnostics, and degraded/disconnected paths, all grounded in the exact BASE scenario. If the live CID expands or changes, the catalog and demo can be regenerated from the same structure and the same surface rules.

## Four-tier UX map: Journey → Flow → Page/Panel → Component

The four-tier model maps user experience from macro to micro as follows:

- Journey: Navigate and govern Rails resources from the VS Code editor as a Cyborg (Human + AI agent) using the 3dot surface.
- Flows: The 17 use cases above (UC-01 through UC-17) that drive discovery, reading, writing, governance, and auditability through the CID surface.
- Page/Panel: The 3dot webview shell, the editor surface, and the Python editor surface for code snippets and call-labels.
- Components: The CID bootstrap flow (discover), the status bar CID indicator, the Activity view, the webview panels for governance, the call-labels after completions, and the editor diagnostics (three/unknown-capability, three/missing-required, three/unexpected-param).

| Journey | Flow | Page / Panel | Components and responsibilities |
|---|---|---|---|
| Navigate and govern Rails resources from the editor | UC-01 discovery and UC-16 hot-reload; UC-17 offline path | 3dot webview shell; Python editor surface; status bar | BACK URL bootstrap; CID.json seed; CID/op-count indicator; offline/disconnected state; `.threedot/cid.json` viewer; hot-reload listener |
| Navigate and govern Rails resources from the editor | UC-02 through UC-05: context onboarding and contract learning | Python editor surface; webview PULL results; F12 CID view | Completion-based noteList/noteGet usage; import three; go-to CID (F12); show call labels |
| Understand operational boundaries | UC-06 through UC-09: governance, diagnostics, and safe writes | Activity view; CID definition view | Role-based grouping (context, governance, etc.); diagnostic surfaces; closed-shape validation; pre-dispatch checks |
| Issue and recover a safe effect | UC-10 through UC-12: write, idempotent replay, and governance audit | Webview push panel; governance panels | Push with operationId; never-raise result; idempotency; l8.* reads; journal/receipts |
| Auditability and boundary enforcement | UC-13 through UC-17: private_local boundary, agent parity, journey readiness, and degraded scenarios | Cyborg Journey panel; governance/readouts | Boundary validation; synchronized agent-human work; offline and recovery paths |

This four-tier mapping demonstrates a cohesive, buildable integration experience grounded entirely in the BASE scenario.

## What this proves

The BASE scenario proves that a plain Rails app, when projected as a CID at /_cpcp, becomes safely navigable and operable from inside the code editor by both human and AI agent. OSI Level 8 governance provides auditable traces of context, effects, and governance reads, while the private_local boundary remains within BACK. The 3dot surface translates the live CID contract into language-native completions, reference-driven reads, and a controlled push path, all with explicit diagnostics and per-step evidence gates. This design ensures that every effect is observable, validateable, and auditable, and that agent-assisted workflows remain constrained by the same CID rules as human workflows.

## Source basis and references

This catalog and demo are grounded entirely in the provided BASE scenario and its explicit enumerations of operations and governance boundaries. Any extension of the CID surface or changes to the SHACL constraints would be reflected in an updated catalog generated from the same process.

> References are derived from the user-provided BASE scenario description and its explicit operation definitions. See the BASE content attached to the prompt for the authoritative model.

### References

[1] User-provided BASE scenario and required deliverables (BASE 0–4, 5–9 details, and operation definitions) - local copy of the prompt-pasted content

---

### Attachments delivered with this run
- threedot_cpcp_use_case_catalog.md (GitHub-ready Markdown catalog, 17 UC entries)
- threedot_demo.py (standalone Python demo artifact)
- threedot_cpcp_use_cases.zip (archive containing the catalog and the demo artifact)

References:
- [1] User-provided BASE scenario and required deliverables, local prompt attachment.

---

## Sources

- pasted_content_fBN071rPcnIos1l3XbUQn6.txt
- /home/ubuntu/threedot_demo.py
- /home/ubuntu/threedot_cpcp_use_case_catalog.md
