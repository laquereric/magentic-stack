# `vv-bpmn-bbo` — relational core first

> ## BUILT 2026-09-11 — schema-only private repo
>
> `https://github.com/laquereric/vv-bpmn-bbo` (private). Local checkout
> `gems/vv-bpmn-bbo`. 7 plants green: seed (LinkML + Actor, no
> `Boolean`), two versions of `Flow_1`, exclusive-gateway default vs
> condition, Actor as linked record (string payload refused),
> ItemDefinition restrict, unresolved CallActivity, no `flows` table
> and no `graph_iri` column.
>
> Not built: XML importer, graph projection, rag.
>
> ## CPCP BUILT 2026-09-11 — owner override of §18
>
> §18 listed "CPCP `bpmn.*`" as out of v1. The owner asked for it, which
> supersedes that line. §14 is untouched and is what the seam is built
> around.
>
> **Vendored, not consumed.** The gem is now `gems/vv-bpmn-bbo` in this
> repo, and its gemspec was retargeted on the way in: ADR 0038 rule 2
> forbids a gemspec under `gems/` naming a `laquereric/` repo other than
> `magentic-stack`, and it arrived pointing at itself — the exact
> configuration 0038 was written about. The standalone private repo is
> now the non-authoritative copy; **0038 rule 3 says archive it, which
> is an owner action on GitHub and was not taken here.** Its nested
> `.git` was parked, not deleted (it was in sync with origin at
> `5c3b84a`, no stashes, no extra branches).
>
> **On BACK, not a new container.** These rows are domain state and ADR
> 0056 makes BACK the writer; a `bpmn` container would have to mount the
> same SQLite beside BACK, which is two writers on one file. I built a
> `ROLE=bpmn` branch first and it was wrong — `bpmn.*` registers through
> `RailsCpcp.project`, the projection the engine already serves, and a
> plant now fails the gate if a ROLE branch reappears.
>
> **Read-only.** `bpmn.deploy` and `bpmn.run.start` are declared and
> refuse `bpmn_write_undecided`: v1 is schema-only so there is no
> importer, and the run tables are a record of execution rather than an
> engine. Starting an instance would write one that never moves, which
> is worse than refusing because it looks like it worked.
>
> **§14 enforced on the read path.** The seam refuses `spec_iri`, `iri`,
> `graph_iri` and `uri` as keys (`identity_not_minted_here`) and derives
> `spec_iri` on the way out. Measured: `Gateway_1` in versions 1 and 2
> yields two IRIs, so the grain really is
> `(definition_key, version, element_id)` and not `element_id` alone.
>
> **Three distinctions kept apart**, each planted: a version that does
> not exist refuses while one nobody has run reports zero; un-migrated
> tables are `bpmn_tables_missing`, not an empty model; a capped node
> list says `truncated` rather than looking complete.
>
> `lib/bpmn_seam.rb` is framework-free so the gate drives it against the
> gem's own migration in memory — 28 assertions, no Rails boot. 12
> plants fire. Sweep 145 ok.

**This file is the database design.** Not the parser, not the BBO lift,
not the CPCP face, not a graph mapping, not a rag collection. Those
follow this schema. Until these tables exist and a process version can
be inserted with foreign keys, nothing else is entitled to claim a
workflow model.

Private Rails engine gem **`vv-bpmn-bbo`**. `Vv::` because it is a
capability the substrate consumes, same class as `vv-base` and
`vv-blob`. It is not `Mm::` and not `Mmg::`.

Source of the *vocabulary*: BPMN 2.0 (ISO/IEC 19510, Chapter 10) via
the BPMN 2.0 Based Ontology (BBO 1.0.0, CC-BY 4.0, IRIT 2019). Source
of the *shape*: ordinary Rails — engine, migrations, STI where BPMN
has a class hierarchy, `belongs_to` / `has_many` where BPMN has a
reference, string enums with inclusion validations because the pod
database is SQLite.

Companion PDF:
`magentic-market-ai/docs/research/bpmn-bbo-lift.pdf`. That note is a
semantic lift. This file is the thing the lift is a projection of.

**Decided 2026-09-11 (owner):** table prefix is **`bpmn_bbo_`**. First
specialized `ar_class` is **`Vv::Base::Actor`**. v1 is **schema-only**
— engine, migrations, models, seeds, plants. No XML importer.

---

## Why relational is first

The stack already has three stores:

| Store | Engine | Algebra | Authority |
|---|---|---|---|
| **Relational** | SQLite via ActiveRecord (BACK / BACKJOB) | rows, FKs, transactions | **the domain record** (ADR 0056, 0057) |
| **Graph** | oxigraph | triples, named graphs | projection of rows (ADR 0032) |
| **Vector** | local Milvus (`rag`) | ANN / BM25 | index of text, never admission |

A BBO lift that writes triples first produces the hairball the PDF
warns about: element ids unique only inside a file, vendor extensions
with no terms, specification mixed with runs. The graph cannot refuse
an ungrounded node if there is no row to ground it on.

So:

1. **BPMN XML remains the interchange** (versioned bytes, content-
   addressed in `vv-blob`).
2. **These tables are the working model** — specification and
   execution.
3. **Graph projects from the rows** (one named graph per
   `bpmn_bbo_definition_versions` row, BBO terms, SHACL later).
4. **Rag indexes the rows** (node name + documentation, id = row id).

If a graph fact and a row disagree, the row wins. If a vector neighbour
and a row disagree, the row wins. That is the whole point of doing this
first.

---

## Rails pattern (the well-known part)

Follow `vv-base`, not an isolate_namespace engine that would prefix
`vv_bpmn_bbo_flow_nodes`.

```ruby
module Vv
  module BpmnBbo
    class Record < ActiveRecord::Base
      self.abstract_class = true
      self.table_name_prefix = "bpmn_bbo_"
    end
  end
end
```

- **Do not** define `::ApplicationRecord`. The gem has its own abstract
  base (`vv-base` README: a gem that defines the host's
  `ApplicationRecord` is stealing the host).
- Table names are `bpmn_bbo_processes`, `bpmn_bbo_flow_nodes`, … —
  BBO-scoped BPMN words, plural, snake_case.
  `Vv::BpmnBbo::Process` → `bpmn_bbo_processes`.
  Run models set `self.table_name` explicitly (`bpmn_bbo_run_*`):
  prefix + `ProcessInstance` would otherwise collide with
  `bpmn_bbo_processes`.
- **Do not** reuse `Vv::Base::Flow`. That is a journey/intent home
  (P9/P10). A BPMN Process is a different thing. No `flows` table, no
  top-level `Flow` constant.
- SQLite. No Postgres enums, no `uuid` columns as PKs, no partial
  indexes that SQLite cannot express. Integer PKs. `t.timestamps`.
  Foreign keys declared in the migration (`foreign_key: true`).
- Optimistic lock on **run** rows only (`lock_version`) — two writers
  (BACK / BACKJOB) already share the file.
- `dependent: :destroy` on composition (a version owns its nodes).
  `dependent: :restrict_with_error` on catalogs that instances point
  at (you cannot delete an `ItemDefinition` a variable still uses).
- No `graph_iri` column. Subject IRIs are derived from class + id, the
  same rule as AR-grounded triples. The mint the PDF wants —
  `(definition_key, version, element_id)` — is a **unique index**, and
  a method, not a stored IRI.

IRI method, later, not a column:

```ruby
def spec_iri
  key = definition_version.package.definition_key
  ver = definition_version.version
  "urn:mm:bpmn:#{key}:#{ver}:#{element_id}"
end
```

---

## Two worlds, two prefixes, one database

BBO models **specification**. It does not keep run history (PDF
hazard 3). Stretching BBO to hold instances is how specification and
execution blur. Rails has always split this: the recipe and the order.

| World | Table prefix | What a row is | Destroying it |
|---|---|---|---|
| **Spec** | `bpmn_bbo_` | a definition element in a versioned model | cascade inside the version |
| **Run** | `bpmn_bbo_run_` | a token, a job, a variable, an incident | never rewrites spec rows |

A run row **belongs_to** a spec row. Spec never belongs_to run. That
FK direction is the specialization seam: a domain (translation board,
medallion memory, a customer's Camunda export) adds ItemDefinitions
and performers that point at *its* AR classes; execution then holds
values as links to those records.

```
bpmn_bbo_packages
  └─ bpmn_bbo_definition_versions          1 named graph later, 1 blob
       ├─ bpmn_bbo_processes
       │    ├─ bpmn_bbo_flow_nodes (STI)
       │    ├─ bpmn_bbo_sequence_flows
       │    ├─ bpmn_bbo_lane_sets / bpmn_bbo_lanes
       │    └─ bpmn_bbo_item_aware_elements (STI)
       ├─ bpmn_bbo_item_definitions ──► bpmn_bbo_datatypes
       ├─ bpmn_bbo_expressions
       ├─ bpmn_bbo_messages / signals / errors / escalations
       └─ bpmn_bbo_event_definitions (STI, second axis on Events)

bpmn_bbo_run_process_instances ──► bpmn_bbo_processes
  ├─ bpmn_bbo_run_activity_instances ──► bpmn_bbo_flow_nodes
  ├─ bpmn_bbo_run_jobs
  ├─ bpmn_bbo_run_variables ──► bpmn_bbo_datatypes + bpmn_bbo_typed_values
  └─ bpmn_bbo_run_incidents
```

---

## 1. Packages and versions

BPMN's root is `Definitions`. Element ids are unique **inside a
file**, not across the portfolio (PDF hazard 2). The grain of identity
is `(definition_key, version, element_id)`.

### `bpmn_bbo_packages`

One process portfolio entry. The stable key, independent of file path.

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `definition_key` | string, **unique**, not null | Camunda/Flowable key; never a path |
| `name` | string | |
| `target_namespace` | string | BPMN `targetNamespace` |
| `ledger_placement` | string, not null, default `canonical` | same vocab as `Vv::Base::LedgerPlaced` |

### `bpmn_bbo_definition_versions`

One row per XML revision. This is the unit the PDF wants as a named
graph, and the unit `vv-blob` addresses.

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `package_id` | FK `bpmn_bbo_packages`, not null | |
| `version` | string, not null | the definition version, not a gem version |
| `source_digest` | string, not null | `sha256:…` from `vv-blob` |
| `exporter` | string | `camunda` / `flowable` / `signavio` / `hand` |
| `exported_at` | datetime | |
| `is_latest` | boolean, not null, default false | materialized; maintained in a transaction with insert |

Unique `(package_id, version)`. Unique `source_digest` is **not**
required — two keys may share bytes. Index `(package_id, is_latest)`.

The XML bytes live in `vv-blob`. This table holds the digest, not a
`text` column of XML. `bpmndi:*` is dropped at parse; it never
becomes rows.

---

## 2. Collaboration (optional; present when the file has it)

### `bpmn_bbo_collaborations`

`definition_version_id` FK, `element_id`, `name`. Unique
`(definition_version_id, element_id)`.

### `bpmn_bbo_participants`

`collaboration_id` FK, `element_id`, `name`, `process_id` nullable FK
to `bpmn_bbo_processes` (a participant may be an empty pool).

### `bpmn_bbo_message_flows`

`collaboration_id` FK, `element_id`, `source_participant_id`,
`target_participant_id`, optional `source_node_id` / `target_node_id`
(message flows can attach to a participant or to a node), optional
`message_id` FK to `bpmn_bbo_messages`.

---

## 3. Process

### `bpmn_bbo_processes`

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `definition_version_id` | FK, not null | |
| `element_id` | string, not null | id inside the file |
| `name` | string | |
| `is_executable` | boolean, not null, default false | |
| `process_type` | string | `none` / `public` / `private` |
| `is_closed` | boolean, not null, default false | |
| `callable` | boolean, not null, default false | BBO `CallableElement` — may be the target of a CallActivity |

Unique `(definition_version_id, element_id)`.

A CallActivity's `calledElement` is a **key**, not a row in another
file. Store both:

### on `bpmn_bbo_flow_nodes` when `type` is `Vv::BpmnBbo::CallActivity`

| column | type | notes |
|---|---|---|
| `called_definition_key` | string | version-agnostic |
| `called_process_id` | FK `bpmn_bbo_processes`, nullable | version-specific, when resolved |

PDF hazard 5: expect to want both. The key is always stored. The FK is
filled when that version exists in *this* database. Unresolved is a
null FK, not a dangling string pretending to be a row.

---

## 4. Flow nodes — STI

BBO: `FlowNode` generalizes `Activity`, `Event`, `Gateway`. Rails STI
is the standard mapping of that hierarchy onto one table. One query
returns the graph of a process; subclasses carry the extra columns
that only they use (those columns live on the same table, nullable,
which is the STI trade-off and is acceptable here — the extra columns
are few).

### `bpmn_bbo_flow_nodes`

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `type` | string, not null | STI class name, **full** `Vv::BpmnBbo::UserTask` |
| `process_id` | FK, not null | |
| `element_id` | string, not null | |
| `name` | string | |
| `default_flow_id` | FK `bpmn_bbo_sequence_flows`, nullable | gateways / activities with a default |
| `called_definition_key` | string | CallActivity only |
| `called_process_id` | FK `bpmn_bbo_processes`, nullable | CallActivity only |
| `loop_characteristics_id` | FK, nullable | |
| `attached_to_id` | FK `bpmn_bbo_flow_nodes`, nullable | BoundaryEvent only |
| `cancel_activity` | boolean | BoundaryEvent interrupting flag |
| `event_gateway_type` | string | EventBasedGateway exclusive/parallel |
| `gateway_direction` | string | `unspecified` / `converging` / `diverging` / `mixed` |

Unique `(process_id, element_id)`. Index `type`. Index
`attached_to_id`.

STI tree (BPMN 2.0 Chapter 10, the BBO fragment):

```
FlowNode
├─ Activity
│  ├─ Task
│  │  ├─ UserTask
│  │  ├─ ServiceTask
│  │  ├─ ScriptTask
│  │  ├─ ManualTask
│  │  ├─ BusinessRuleTask
│  │  ├─ SendTask
│  │  └─ ReceiveTask
│  ├─ SubProcess
│  │  └─ AdHocSubProcess
│  └─ CallActivity
├─ Gateway
│  ├─ ExclusiveGateway
│  ├─ InclusiveGateway
│  ├─ ParallelGateway
│  ├─ ComplexGateway
│  └─ EventBasedGateway
└─ Event
   ├─ StartEvent
   ├─ EndEvent
   ├─ IntermediateCatchEvent
   ├─ IntermediateThrowEvent
   └─ BoundaryEvent
```

Store the **full class name** in `type` so a host that also has a
`UserTask` constant does not instantiate the wrong class.

`SubProcess` is both a `FlowNode` and a container. Child nodes still
`belong_to :process` (the executable process). Containment is a
separate optional `container_node_id` FK on `bpmn_bbo_flow_nodes` pointing
at the SubProcess row. Null means the node sits on the process
itself. Do not invent a second processes table for embedded
subprocesses.

---

## 5. Sequence flows

### `bpmn_bbo_sequence_flows`

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `process_id` | FK, not null | |
| `element_id` | string, not null | |
| `name` | string | |
| `source_id` | FK `bpmn_bbo_flow_nodes`, not null | |
| `target_id` | FK `bpmn_bbo_flow_nodes`, not null | |
| `condition_expression_id` | FK `bpmn_bbo_expressions`, nullable | reified, not a string column |
| `is_immediate` | boolean | |

Unique `(process_id, element_id)`. Index `source_id`, `target_id`.

Both ends are flow nodes, so this is two `belongs_to`s, **not**
polymorphic. A polymorphic source/target here would be a Rails
anti-pattern: the type is known.

`default_flow_id` on the node plus `condition_expression_id` on the
flow is how exclusive gateways keep a default distinct from
conditioned flows (PDF mapping table).

---

## 6. Expressions — a row, not a literal

PDF: keep the body as an opaque literal; do not parse FEEL or JUEL.
BBO reifies the condition as an `Expression` individual. That is an
AR record.

### `bpmn_bbo_expressions`

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `definition_version_id` | FK, not null | |
| `element_id` | string, nullable | not every expression has an XML id |
| `kind` | string, not null | `expression` / `formal_expression` |
| `language` | string | `feel` / `juel` / `javascript` / null |
| `body` | text, not null | **opaque** |
| `evaluates_to_id` | FK `bpmn_bbo_datatypes`, nullable | FormalExpression type |

SequenceFlow, ComplexGateway, TimerEventDefinition, StandardLoop
`loopCondition` all `belong_to` this table. The body is never inlined
on the owner. That is the first half of "datatypes as linked records":
an expression is a thing, and what it evaluates to is a datatype row.

---

## 7. Datatypes as linked records

This is the load-bearing design. BPMN's type system is
`ItemDefinition` + `structureRef`. Implementations usually stuff a
QName string into a column (`xsd:string`, `java.lang.String`, a JSON
schema URL) and then cannot join a variable to an Actor, a Note, or a
Meaning.

Here a type **is a row**. A value **is a row that points at that
type**. When the type is an AR class, the value **is a foreign key to
that class**.

### `bpmn_bbo_datatypes`

A catalog, not versioned with a process (XSD and LinkML builtins are
seeded once). A process may add `item_structure` rows that belong to
a version.

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `kind` | string, not null | `xsd` / `linkml` / `ar_class` / `item_structure` / `unit` |
| `name` | string, not null | `string`, `integer`, `Vv::Base::Actor` |
| `uri` | string | XSD / LinkML / UO IRI; null for `ar_class` |
| `ar_class_name` | string | required when `kind = ar_class` |
| `unit_iri` | string | BBO imports UO; only `kind = unit` |
| `parent_id` | FK self, nullable | restriction / collection-of |
| `is_collection` | boolean, not null, default false | |
| `definition_version_id` | FK, nullable | null = catalog; set = process-local structure |
| `structure_schema` | text | JSON Schema or LinkML class name for `item_structure` |

Unique `(kind, name)` where `definition_version_id` is null (the
catalog). Unique `(definition_version_id, name)` where it is set.

Seed from `Vv::Linkml::Types::BUILTIN` (19 types, lower-case names)
plus the XSD URIs they already carry. Do not invent a parallel
`Boolean` / `XSDDate` list — that is the trap `vv-linkml` exists to
make loud.

Seed **one** `ar_class` row with the catalog:

| kind | name | ar_class_name |
|---|---|---|
| `ar_class` | `Vv::Base::Actor` | `Vv::Base::Actor` |

That is the first specialization, owner-decided. Further `ar_class`
rows (Session, Meaning, Entry, …) are data, added when a domain
needs them. `kind = ar_class` is how this engine specializes: the
datatype row names the class; the typed value points at a row of
that class.

### `bpmn_bbo_item_definitions`

BPMN `ItemDefinition`. Always linked to a datatype. Never a free
`structureRef` string.

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `definition_version_id` | FK, not null | |
| `element_id` | string, not null | |
| `item_kind` | string, not null | `information` / `physical` |
| `datatype_id` | FK `bpmn_bbo_datatypes`, **not null** | the ground |
| `is_collection` | boolean, not null, default false | |

Unique `(definition_version_id, element_id)`.

### `bpmn_bbo_typed_values`

A value at rest. Spec defaults and run variables both point here.
Exactly one payload column is set, and it must match `datatype.kind`.

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `datatype_id` | FK, not null | |
| `string_value` | text | xsd/linkml string-like |
| `integer_value` | integer | |
| `decimal_value` | decimal | |
| `boolean_value` | boolean | |
| `datetime_value` | datetime | |
| `json_value` | text | `item_structure` that is not an AR class |
| `blob_digest` | string | large / opaque; bytes in `vv-blob` |
| `record_type` | string | **AR class name** |
| `record_id` | integer | **that class's PK** |

Check in the model (and a SQLite trigger, same lesson as
MeaningActivations: a validation is not a constraint):

- `kind = ar_class` → `record_type` equals `datatype.ar_class_name`,
  `record_id` present, scalar columns null. `record_type.constantize.find(record_id)`
  must exist at write.
- `kind = xsd` / `linkml` → the matching scalar column is set, record
  columns null.
- `kind = item_structure` → `json_value` or a nested structure table
  later; v1 is `json_value`.
- `kind = unit` → `decimal_value` + the unit lives on the datatype.

`belongs_to :record, polymorphic: true` is allowed **only here**,
because the whole point of `ar_class` is that the target class varies.
Everywhere else in this schema the target class is known and the FK is
plain.

This is "ground datatypes in AR linked records": a UserTask output
typed `Vv::Base::Actor` does not store a name string. It stores
`record_type='Vv::Base::Actor', record_id=42`. Graph and rag can only
name that actor by projecting that row.

---

## 8. Item-aware elements (data on the spec)

BPMN `ItemAwareElement`: DataObject, DataStore, Property, DataInput,
DataOutput, and their references.

### `bpmn_bbo_item_aware_elements` (STI)

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `type` | string, not null | `DataObject`, `DataObjectReference`, `DataStore`, `Property`, `DataInput`, `DataOutput` |
| `process_id` | FK, not null | |
| `element_id` | string, not null | |
| `name` | string | |
| `item_definition_id` | FK `bpmn_bbo_item_definitions`, nullable | |
| `data_state` | string | BPMN dataState name |
| `is_collection` | boolean, not null, default false | |
| `default_value_id` | FK `bpmn_bbo_typed_values`, nullable | |

### `bpmn_bbo_data_associations`

`process_id`, `element_id`, `kind` (`input` / `output`),
`source_element_id` FK to `bpmn_bbo_item_aware_elements`,
`target_element_id` FK same, optional `transformation_expression_id`
FK to `bpmn_bbo_expressions`.

---

## 9. Event definitions — second axis

PDF: event definitions are a second axis; do not collapse them into
the event type. A StartEvent that is a message start is still a
`StartEvent` row plus a `MessageEventDefinition` row.

### `bpmn_bbo_event_definitions` (STI)

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `type` | string, not null | `MessageEventDefinition`, `TimerEventDefinition`, `ErrorEventDefinition`, `SignalEventDefinition`, `ConditionalEventDefinition`, `EscalateEventDefinition`, `CompensateEventDefinition`, `LinkEventDefinition`, `TerminateEventDefinition`, `CancelEventDefinition` |
| `event_id` | FK `bpmn_bbo_flow_nodes`, not null | |
| `message_id` | FK `bpmn_bbo_messages` | Message* |
| `signal_id` | FK `bpmn_bbo_signals` | Signal* |
| `error_id` | FK `bpmn_bbo_errors` | Error* |
| `escalation_id` | FK `bpmn_bbo_escalations` | |
| `time_cycle` / `time_date` / `time_duration` | string, nullable | Timer*; ISO-8601 stored as text |
| `condition_expression_id` | FK `bpmn_bbo_expressions` | Conditional* |
| `activity_ref_id` | FK `bpmn_bbo_flow_nodes` | Compensate* |

Catalogs, per definition version:

- `bpmn_bbo_messages` — `element_id`, `name`, `item_definition_id`
- `bpmn_bbo_signals` — `element_id`, `name`, `structure_datatype_id`
- `bpmn_bbo_errors` — `element_id`, `name`, `error_code`, `structure_datatype_id`
- `bpmn_bbo_escalations` — `element_id`, `name`, `escalation_code`

---

## 10. Loop characteristics

### `bpmn_bbo_loop_characteristics` (STI)

`StandardLoopCharacteristics` vs `MultiInstanceLoopCharacteristics`.
Keep sequential vs parallel (PDF: it is a meaningful distinction).

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `type` | string, not null | |
| `is_sequential` | boolean, not null, default true | multi-instance |
| `loop_condition_id` | FK `bpmn_bbo_expressions` | standard |
| `loop_maximum` | integer | standard |
| `test_before` | boolean | standard |
| `loop_cardinality_id` | FK `bpmn_bbo_expressions` | multi |
| `completion_condition_id` | FK `bpmn_bbo_expressions` | multi |
| `collection_item_aware_id` | FK `bpmn_bbo_item_aware_elements` | the collection being looped |

`bpmn_bbo_flow_nodes.loop_characteristics_id` points here.

---

## 11. Lanes and the BBO organizational layer

BPMN has `lane` / `participant`. BBO adds **Agent**, **Role**, **Job**
as separate concepts so two people with the same job can have
different authorization. The BPMN metamodel does not. We store both.

### `bpmn_bbo_lane_sets` / `bpmn_bbo_lanes`

`process_id`, `element_id`, `name`, `parent_lane_id` (nested lanes),
`lane_set_id`. A join table `bpmn_bbo_lane_flow_nodes` (`lane_id`,
`flow_node_id`) — a node may be drawn in one lane; the join keeps that
honest if a later importer disagrees.

### `bpmn_bbo_org_jobs`

BBO Job. Catalog: `name`, unique `key`.

### `bpmn_bbo_org_roles`

BBO Role. Catalog: `name`, unique `key`. **Not** `Vv::Base::Persona`.

### `bpmn_bbo_org_agents`

BBO Agent. `kind` `human` / `software`. Optional `actor_id` integer
pointing at `Vv::Base::Actor` — **no SQL FK** to `actors`, because
`vv-base` may not be loaded in every host. The model validates the
actor exists when `vv-base` is present. A human agent without an
Actor is still an agent; a typed value of datatype `Vv::Base::Actor`
is not — that value *must* resolve.

### `bpmn_bbo_resource_roles`

The assignment on an Activity (potentialOwner, humanPerformer, …).

| column | type | notes |
|---|---|---|
| `flow_node_id` | FK, not null | |
| `kind` | string | `potential_owner` / `human_performer` / `performer` |
| `agent_id` | FK nullable | |
| `org_role_id` | FK nullable | candidate group |
| `org_job_id` | FK nullable | |
| `assignment_expression_id` | FK `bpmn_bbo_expressions` nullable | BBO `has_resourceAssignmentExpression` |

Exactly one of agent / org_role / org_job / expression is expected;
the model enforces it. This is where "which processes assign a user
task to a role that no longer exists" becomes a join, which is the
first portfolio query the PDF exists for.

---

## 12. Documentation and vendor extensions

### `bpmn_bbo_documentations`

`subject_type` + `subject_id` polymorphic **only** because documentation
hangs off many spec tables. `text`, `text_format` (`text/plain`,
`text/html`). Rag later indexes these rows. Documentation is not a
column on every table.

### `bpmn_bbo_extension_values`

PDF hazard 1: the questions people actually ask live in `camunda:*` /
`flowable:*`. BBO has no terms. **Separate namespace, disjoint from
BBO.**

| column | type | notes |
|---|---|---|
| `owner_type` / `owner_id` | polymorphic | the spec row |
| `namespace` | string, not null | `http://camunda.org/schema/1.0/bpmn` |
| `local_name` | string, not null | `assignee`, `formKey`, `retryTimeCycle` |
| `value_id` | FK `bpmn_bbo_typed_values` | typed, not a string kitchen sink |

Do not put Camunda fields on `bpmn_bbo_flow_nodes`. An assignee that is a
user is a typed value of `kind = ar_class` pointing at an Agent or
Actor. That is more work than the BBO mapping, as the PDF says, and
it is the work.

A later local vocabulary (`ex:`) can grow real columns. Until then
this table is the honest parking place.

---

## 13. Execution (`bpmn_bbo_run_*`)

Not BBO. Linked **to** BBO/spec rows. This is the Process Run Crate /
PROV-O slot the PDF puts in a separate graph — here it is a separate
table family, which is the relational equivalent.

### `bpmn_bbo_run_process_instances`

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `process_id` | FK `bpmn_bbo_processes`, not null | the spec version being run |
| `parent_id` | FK self, nullable | call-activity / subprocess instance |
| `business_key` | string | |
| `state` | string, not null | `running` / `suspended` / `completed` / `terminated` / `compensating` |
| `started_at` / `ended_at` | datetime | |
| `start_user_agent_id` | FK `bpmn_bbo_org_agents` nullable | |
| `lock_version` | integer, not null, default 0 | |

Index `(process_id, state)`, index `business_key`.

### `bpmn_bbo_run_activity_instances`

A token / execution at a flow node. Not an event stream (that is
journal / BUS). This is the current and historical *position*.

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `process_instance_id` | FK, not null | |
| `flow_node_id` | FK `bpmn_bbo_flow_nodes`, not null | |
| `parent_id` | FK self, nullable | |
| `state` | string | `active` / `waiting` / `completed` / `terminated` / `compensating` |
| `started_at` / `ended_at` | datetime | |
| `lock_version` | integer | |

### `bpmn_bbo_run_jobs`

Work to do: user task, service task, timer, async continuation.
BACKJOB claims these.

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `process_instance_id` | FK, not null | |
| `activity_instance_id` | FK, not null | |
| `flow_node_id` | FK, not null | |
| `kind` | string | `user` / `service` / `script` / `timer` / `message` / `signal` |
| `state` | string | `open` / `claimed` / `completed` / `failed` / `cancelled` |
| `assignee_agent_id` | FK `bpmn_bbo_org_agents` nullable | |
| `due_at` | datetime | |
| `retries` | integer, not null, default 0 | |
| `claimed_at` / `claimed_by` | | BACKJOB worker identity |
| `lock_version` | integer | |

### `bpmn_bbo_run_variables`

| column | type | notes |
|---|---|---|
| `id` | integer PK | |
| `process_instance_id` | FK, not null | |
| `activity_instance_id` | FK nullable | local vs process scope |
| `name` | string, not null | |
| `item_definition_id` | FK nullable | when the spec declared one |
| `value_id` | FK `bpmn_bbo_typed_values`, **not null** | |

Unique `(process_instance_id, activity_instance_id, name)` with
`activity_instance_id` using a sentinel or two indexes (SQLite unique
+ nulls: use a generated `scope_key` string `#{pi_id}:#{ai_id or '-'}:#{name}`
unique, because SQLite unique allows multiple nulls).

### `bpmn_bbo_run_incidents`

`job_id` FK, `kind`, `message`, `created_at`, `resolved_at`. Failed
jobs do not dump the reason into `jobs.state` only.

### `bpmn_bbo_run_event_subscriptions`

Waiting for a message / signal / timer. `process_instance_id`,
`activity_instance_id`, `kind`, `name` (message/signal name),
`due_at` (timers).

Run rows do not store a copy of the spec. They point. Replaying a run
against a different `process_id` is a different instance, not an
update in place.

---

## 14. What graph and rag are allowed to do (not designed here)

They **follow** these keys.

**Graph.** One named graph per `bpmn_bbo_definition_versions.id`. Subjects
are spec-row IRIs. Predicates are BBO (vendored copy of `BBO.owl`,
never fetched from IRIT at runtime — PDF hazard 4). `camunda:*` /
`flowable:*` live in a disjoint local vocabulary projected from
`bpmn_bbo_extension_values`. Run history is a **second** named graph per
`bpmn_bbo_run_process_instances.id`, PROV-O shaped, later. SHACL
validates the spec graph; it does not prove deadlock freedom (PDF
hard limit).

**Rag.** Chunks are `bpmn_bbo_documentations.text` plus `name` of the
owning spec row. The chunk id **is** `bpmn_bbo_documentations.id` (or
`bpmn_bbo_flow_nodes.id` when there is no documentation row). No chunk
without a row. Writes still wait on `rag_write_undecided`.

Neither store is a place to mint identity. `(definition_key, version,
element_id)` and integer PKs are.

---

## 15. Migration order

One migration family, ordered so FKs exist:

1. `bpmn_bbo_packages`, `bpmn_bbo_datatypes` (seed XSD + LinkML
   builtins **and** `Vv::Base::Actor` as `ar_class`, via
   `Vv::BpmnBbo::Datatype.seed!`)
2. `bpmn_bbo_definition_versions`
3. `bpmn_bbo_typed_values` (needs datatypes)
4. `bpmn_bbo_collaborations`, `bpmn_bbo_processes`
5. `bpmn_bbo_expressions`, `bpmn_bbo_item_definitions`, catalogs (messages,
   signals, errors, escalations)
6. `bpmn_bbo_loop_characteristics`, `bpmn_bbo_flow_nodes`
7. `bpmn_bbo_sequence_flows` then add `default_flow_id` on nodes (cycle:
   create nodes, create flows, update nodes — two migrations or a
   deferred assignment in the importer)
8. `bpmn_bbo_event_definitions`, `bpmn_bbo_item_aware_elements`,
   `bpmn_bbo_data_associations`
9. `bpmn_bbo_lane_sets`, `bpmn_bbo_lanes`, `bpmn_bbo_lane_flow_nodes`
10. `bpmn_bbo_org_jobs`, `bpmn_bbo_org_roles`, `bpmn_bbo_org_agents`,
    `bpmn_bbo_resource_roles`
11. `bpmn_bbo_documentations`, `bpmn_bbo_extension_values`
12. `bpmn_bbo_participants`, `bpmn_bbo_message_flows`
13. `bpmn_bbo_run_process_instances` → activity_instances → jobs →
    variables → incidents → event_subscriptions

Cycle at step 7 is the only one. Do not use `has_and_belongs_to_many`
anywhere; every join is an explicit model if it might grow a column
(`bpmn_bbo_lane_flow_nodes` already will, the first time someone stores
`order`).

---

## 16. Associations (the Rails you actually write)

```ruby
class Vv::BpmnBbo::Package < Record
  include Vv::Base::LedgerPlaced
  has_many :definition_versions, dependent: :destroy
end

class Vv::BpmnBbo::DefinitionVersion < Record
  belongs_to :package
  has_many :processes, dependent: :destroy
  has_many :datatypes, dependent: :destroy  # version-local structures only
end

class Vv::BpmnBbo::Process < Record
  belongs_to :definition_version
  has_many :flow_nodes, dependent: :destroy
  has_many :sequence_flows, dependent: :destroy
  has_many :run_instances, class_name: "Vv::BpmnBbo::Run::ProcessInstance"
end

class Vv::BpmnBbo::FlowNode < Record
  belongs_to :process
  belongs_to :container_node, class_name: "FlowNode", optional: true
  belongs_to :loop_characteristics, optional: true
  has_many :outgoing, class_name: "SequenceFlow", foreign_key: :source_id
  has_many :incoming, class_name: "SequenceFlow", foreign_key: :target_id
  has_many :event_definitions, foreign_key: :event_id, dependent: :destroy
  has_many :resource_roles, dependent: :destroy
end

class Vv::BpmnBbo::SequenceFlow < Record
  belongs_to :process
  belongs_to :source, class_name: "FlowNode"
  belongs_to :target, class_name: "FlowNode"
  belongs_to :condition_expression, class_name: "Expression", optional: true
end

class Vv::BpmnBbo::ItemDefinition < Record
  belongs_to :definition_version
  belongs_to :datatype
end

class Vv::BpmnBbo::TypedValue < Record
  belongs_to :datatype
  belongs_to :record, polymorphic: true, optional: true
  validate :payload_matches_datatype
end

class Vv::BpmnBbo::Run::ProcessInstance < Record
  self.table_name = "bpmn_bbo_run_process_instances"
  belongs_to :process
  has_many :activity_instances, dependent: :destroy
  has_many :variables, dependent: :destroy
  has_many :jobs, dependent: :destroy
end

class Vv::BpmnBbo::Run::Variable < Record
  self.table_name = "bpmn_bbo_run_variables"
  belongs_to :process_instance
  belongs_to :item_definition, optional: true
  belongs_to :value, class_name: "Vv::BpmnBbo::TypedValue"
end
```

Never-raise at the gem boundary. `save` returning false is a
validation failure; a public `Vv::BpmnBbo.land(version: …)` returns
`{ ok: true, version: }` or `{ ok: false, reason:, because: }`. That
wrapper is not this file.

---

## 17. Specializing a domain workflow

The core stays BPMN. A domain specializes by **data**, not by forking
the gem:

| Domain need | Where it goes |
|---|---|
| Payload is a Meaning / Actor / Entry | `bpmn_bbo_datatypes` row `kind=ar_class`, `ar_class_name=…` |
| Form key, retry cycle, listener | `bpmn_bbo_extension_values` until they earn a column |
| Candidate group is an org role we already have | `bpmn_bbo_org_roles` + `bpmn_bbo_resource_roles` |
| "This run is about session 44" | `bpmn_bbo_run_variables` named `session`, value → `Vv::Base::Session` |
| Search "which processes mention payments" | rag over `bpmn_bbo_documentations`, grounded by row id |
| "Which processes call the payments subprocess" | `CallActivity.called_definition_key` join |

No domain table inside this gem. No `translation_board_processes`
STI. If a domain needs a column on every UserTask, that is an
extension value or a follow-up migration with a real name, not a
JSON blob on `bpmn_bbo_flow_nodes`.

---

## 18. Out of v1 (relational)

- Choreography, conversation, bpmndi (layout).
- Petri-net soundness tables.
- History tables separate from `bpmn_bbo_run_*` (these *are* the run
  record; an archive later copies completed instances out).
- Graph projection, SHACL, rag upsert. ~~CPCP `bpmn.*`~~ — **built
  2026-09-11 by owner override**; see the header. Read-only, registered
  on BACK, writes refused by name.
- A Camunda/Flowable XML importer (owner: schema-only in v1).
- PKO / FBK ontologies as alternative cores. BBO is the pinned spec
  vocabulary; PKO would be a different gem if run-data-as-ontology
  ever becomes the point.

---

## 19. Acceptance for this design (when it is built)

A plant, not a paragraph:

1. Seed datatypes. `Vv::Linkml::Types.names` are rows. `Boolean` is
   not a name. Catalog includes `kind=ar_class` /
   `ar_class_name=Vv::Base::Actor`.
2. Insert a package + version with a blob digest. Two versions of the
   same `definition_key` coexist. Element id `Flow_1` in each is two
   `bpmn_bbo_flow_nodes` rows.
3. Exclusive gateway with two outgoing flows: one has
   `condition_expression_id`, one is the node's `default_flow_id`.
   No condition body lives on the flow row.
4. A UserTask output `ItemDefinition` of `kind=ar_class`
   `Vv::Base::Actor`. A run variable whose typed value points at
   `Actor.find(id)`. A typed value with a name string in
   `string_value` for that datatype **refuses**.
5. Deleting an `ItemDefinition` that a run variable still references
   **refuses** (`restrict_with_error`).
6. `CallActivity` with `called_definition_key` and a null
   `called_process_id` is valid. Filling the FK when that process
   version lands does not rewrite the key.
7. No table named `flows`. No column named `graph_iri`. Every spec
   table begins `bpmn_bbo_`; every run table begins `bpmn_bbo_run_`.

---

## Open questions (owner)

None. Prefix, Actor, and schema-only are decided. An XML importer is
a later gem-surface; it will fight Camunda extensions when it exists,
not before these tables do.
