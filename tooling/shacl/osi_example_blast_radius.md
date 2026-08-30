# osi.example blast radius

Status: enumeration only. No IRI was renamed. No TTL, catalog, or
checker was edited to "tidy" a reference.

Measured on `ab6e4f7` (step 9 on main). Token search: `osi.example`.

| | this inventory | Claude's brief |
|---|---:|---:|
| files | **12** | 12 |
| occurrences | **49** | 49 |

The counts match. Claude's "2 in TTL that step 9 relocated" is **2 files**
(5 prefix lines). "6 of them in ProfileCatalog" is the 6 catalog IRIs.

## Unique IRIs (the live protocol surface)

Six NodeShape IRIs, all under `https://osi.example/shapes/`:

| IRI | wrap / catalog | execution |
|---|---|---|
| `https://osi.example/shapes/P1NoteCreateEffectShape` | `P1::NoteCreateEffectShape` request | runtime |
| `https://osi.example/shapes/P1NoteCreateContextShape` | `P1::NoteCreateContextShape` response | runtime |
| `https://osi.example/shapes/P1NoteListPullShape` | `P1::NoteListPullShape` request | runtime |
| `https://osi.example/shapes/P1NoteListContextShape` | `P1::NoteListContextShape` response | runtime |
| `https://osi.example/shapes/P4NoteCreateEffectShape` | `P4::NoteCreateEffectShape` (Grounding alias of P1 create) | runtime |
| `https://osi.example/shapes/P4DurableReceiptShape` | catalogued; no wrap; `execution=none` | not runtime-bound |

Three more IRI *prefixes* appear only as Turtle `@prefix` (property/shape
namespaces, not catalog keys):

| prefix | IRI | used as |
|---|---|---|
| `osi:` | `https://osi.example/shapes/` | NodeShape subjects (`osi:P1NoteCreateEffectShape`) and `sh:path osi:items` |
| `note:` | `https://osi.example/ns/level-8/profile-1/note#` | `sh:path note:title`, `note:body`, `note:id`, `note:ledgerPlacement` |
| `p4:` | `https://osi.example/ns/level-8/profile-4/execution#` | `sh:path p4:receiptCid`, `p4:status`, `p4:operationRequestCid` |

P10 docs still show `https://osi.example/ns/level-8/profile-10/intent#`. The
**live** Profile 10 TTL uses `https://w3id.org/cpcp/osi8/intent#`. Those three
doc hits are stale skeleton, not runtime.

---

## 1. Catalog / Ruby string dispatch

Dispatch itself is the Ruby name (`"P1::NoteCreateEffectShape"`), not the
IRI. Grounding's `when` branches never see `osi.example`. Renaming the IRI
does **not** change what Grounding refuses.

The IRI is still load-bearing: `ProfileCatalog::Entry#shape_iri` is copied
onto every `Grounding::Result` as `shape_id`.

| file | line | exact IRI | detected? |
|---|---:|---|---|
| `gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb` | 38 | `https://osi.example/shapes/P1NoteCreateEffectShape` | **silent** |
| same | 39 | `.../P1NoteCreateContextShape` | **silent** |
| same | 40 | `.../P1NoteListPullShape` | **silent** |
| same | 41 | `.../P1NoteListContextShape` | **silent** |
| same | 42 | `.../P4NoteCreateEffectShape` | **silent** |
| same | 43 | `.../P4DurableReceiptShape` | **silent** |

No existing checker compares `Entry#shape_iri` to the TTL NodeShape IRI.
`check_shape_binding` / `check_shape_resolution` key by **local name**.
`check_shape_drift` canons `sh:path` to a local token (`title`, not the
`note:` namespace). A catalog IRI change, or a `@prefix` IRI change that
keeps local names, **passes all 16 checkers**.

---

## 2. Shape-valued constraints

**None.** These two TTL files have no `sh:node`, `sh:qualifiedValueShape`,
`sh:or`, `sh:xone`, or `sh:and` pointing at an `osi.example` NodeShape.

`osi:items` is a **property path** (`sh:path osi:items`), not a shape
reference. A rename of the `osi:` prefix would change that predicate IRI
without any `sh:node` to break.

---

## 3. Target declarations

**None.** No `sh:targetClass` / `sh:targetNode` uses an `osi.example` IRI
in these files (or anywhere else in the token search).

---

## 4. Stored or emitted references  (the load-bearing finding)

Grounding copies `entry.shape_iri` into `Result#shape_id`. That value is
then written and returned:

| emit path | where it lands | durable? |
|---|---|---|
| `CpcpAdapter#create_context!` → `Context#shape_id` | SQLite `osi_l8_contexts.shape_id` NOT NULL | **yes** |
| `CpcpAdapter#record_admission!` → `AdmissionAttempt#shape_id` | SQLite `osi_l8_admission_attempts.shape_id` | **yes** |
| same → `report_json` | `AdmissionAttempt.report_json["shape_id"]` (full `safe_report`) | **yes** |
| `KnownRefusal.new("grounding_refused", inbound.safe_report)` | wire `{ok:false,error:{because:{shape_id:...}}}` | client-visible |
| `Projections.context_list` | PULL `l8.context.list` returns stored `shape_id` | re-emits history |

Journal `grounded` extra keys are `shape_digest` / `shape_digest_v2` /
`shape_artifact_id` only. The journal does **not** currently persist the
IRI. Contexts and admission attempts do.

A rename of the six catalog IRIs therefore:

- does not change admission (dispatch is the Ruby name);
- **orphans every existing `Context` and `AdmissionAttempt` row** whose
  `shape_id` is an `osi.example` IRI;
- changes the wire `because.shape_id` on new refusals;
- is **not** caught by any of the 16 checkers.

That is a silent data migration, not an internal cleanup.

---

## 5. Documentation and ADR prose  (safe to change, listed separately)

| file | lines | what |
|---|---|---|
| `docs/adr/0041-two-shape-gems-role-not-namespace.md` | 66, 82 | namespace is quarantined until a namespace ADR |
| `docs/architecture/SHAPE_GEMS.md` | 37 | same quarantine note |
| `docs/reviews/2026-08-29a-two-shape-gems-manus.md` | 81, 83, 211 | names the defect; calls for a namespace ADR |
| `runtimes/mind-pod/docs/RAILS_OSI_LEVEL_8_IN_DEMO.md` | 528–531, 589 | copy of the old catalog map + a sample `shape_id` |
| `runtimes/mind-pod/docs/OSI_LEVEL_8_INTENT_PROFILE.md` | 75, 76, 352 | P10 skeleton prefixes; **not** the live P10 TTL |
| `tooling/shacl/assign_shape_owners.py` | 14, 42, 52, 138 | owner heuristic (`osi.example` ⇒ application) |

---

## Inventory JSON (mirrors, not a seventh kind)

These store the same six IRIs the catalog uses. They are not emit paths.
A rename that did not `--write` them would desync the inventories; binding
still keys by local name, so that desync is **mostly silent**.

| file | hits | notes |
|---|---:|---|
| `tooling/shacl/shape_binding_manifest.json` | 6 | `shapes[].iris[]` |
| `tooling/shacl/shape_owner_candidates.json` | 7 | 6 IRIs + 1 heuristic string |
| `tooling/shacl/shape_quarantine_inventory.json` | 7 | 6 IRIs; `P4DurableReceiptShape` appears twice (lines 1351 and 5112) |

Quarantine inventory still names the **pre-step-9** path
`gems/rails-osi-level-8/data/osi-level-8/profile-4-durable-execution.ttl`.
Not an `osi.example` problem; noted so it is not mistaken for a live load.

---

## TTL prefixes (the two relocated files)

Not in Claude's five kinds as "shape-valued" or "targets". They are the
RDF identity of the NodeShapes and of the `note:` / `p4:` properties.

| file | line | token |
|---|---:|---|
| `gems/shapes-application/contracts/mind-pod/profile-1-cyborg-channel.ttl` | 17 | `@prefix osi: <https://osi.example/shapes/>` |
| same | 19 | `@prefix note: <https://osi.example/ns/level-8/profile-1/note#>` |
| `gems/shapes-application/contracts/mind-pod/profile-4-durable-execution.ttl` | 14 | `@prefix osi:` same |
| same | 16 | `@prefix note:` same |
| same | 17 | `@prefix p4: <https://osi.example/ns/level-8/profile-4/execution#>` |

Subjects `osi:P1NoteCreateEffectShape` etc. expand to the six catalog IRIs.
`sh:path note:title` expands to `https://osi.example/ns/level-8/profile-1/note#title`.
Drift canons that to `title`. Prefix IRI change: **silent**.

No `sh:node` / `sh:targetClass` on these IRIs (kinds 2 and 3 empty).

---

## Token budget (49 = 12 files)

| file | n | kind |
|---|---:|---|
| `profile_catalog.rb` | 6 | 1 catalog |
| `profile-1-cyborg-channel.ttl` | 2 | prefixes |
| `profile-4-durable-execution.ttl` | 3 | prefixes |
| `shape_binding_manifest.json` | 6 | inventory |
| `shape_owner_candidates.json` | 7 | inventory + heuristic |
| `shape_quarantine_inventory.json` | 7 | inventory (DurableReceipt duplicated) |
| `assign_shape_owners.py` | 4 | 5 docs/tooling |
| `0041-two-shape-gems-role-not-namespace.md` | 2 | 5 |
| `SHAPE_GEMS.md` | 1 | 5 |
| `2026-08-29a-two-shape-gems-manus.md` | 3 | 5 |
| `RAILS_OSI_LEVEL_8_IN_DEMO.md` | 5 | 5 (copies the catalog) |
| `OSI_LEVEL_8_INTENT_PROFILE.md` | 3 | 5 (stale P10) |
| **total** | **49** | |

---

## Outside this repo?

`osi.example` is an RFC 2606 reserved name. It is not a published ontology
at a real URL. Live P9/P11/session/P10 shapes already live on
`https://w3id.org/cpcp/osi8/...`.

That does **not** make a rename internal:

- magentic-stack is a public git history; these IRIs are in ADRs and in
  the shipped catalog.
- Any mind-pod that has served `note.create` / `note.list` has
  `osi_l8_contexts.shape_id` (and likely admission-attempt) rows holding
  the IRI. Those rows are the protocol's own history, content-addressed
  next to a `shape_digest`.
- A recorded CID of a context/admission payload that includes `shape_id`
  in JSON would not reverse-map after a rename.

No evidence of a third-party ontology import. Evidence of **durable
first-party records**. Treat as a compatibility event.

---

## Recommendation

**Unsafe to rename without an owner decision (a namespace ADR).**

ADR 0041 already said so: quarantine until a namespace ADR names
successors; do not silently rename.

Reasons, in order:

1. `shape_id` is written into two durable tables and re-emitted on PULL
   and on the refusal wire. That is kind 4, and it is live after step 9.
2. No checker compares catalog IRI ↔ TTL IRI. The 16 checkers would stay
   green across a rename that kept local names. That is the silent class.
3. Dispatch would keep working, so a green rspec would not save you.
   Admission behaviour is the Ruby name; identity of the record is the IRI.

A rename that is allowed later needs, at minimum: successor IRIs, a
mapping from the six old IRIs, a dual-write or lookup for historical
`shape_id`, and a checker that fails if catalog IRI and TTL NodeShape IRI
diverge. That is not this task.

Do not start it from this inventory.
