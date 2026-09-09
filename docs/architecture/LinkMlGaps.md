# LinkML gaps

Measured 2026-09-09 against **linkml 1.11.1** / **linkml-runtime 1.11.1** /
**metamodel 1.11.0**, with the specification gaps read from
`gems/vv-linkml`'s `Unspecified::GAPS` (sourced from `meta.yaml @ 35c91fb0`,
read 2026-09-08).

LinkML is now the source of truth for shapes ([ADR
0069](../adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md)). That
is a decision about where shapes are written, and it is worth taking with the
gaps in view rather than discovering them one production refusal at a time.

**Two kinds of gap, and the distinction is the point.** A *specification* gap
is something LinkML does not define — every implementation picks an
interpretation, and two implementations may pick differently. A *toolchain*
gap is something the reference generators do not do — the specification may be
perfectly clear and the tool still drops it. Conflating them leads to waiting
for an upstream fix that is not coming, or working around a tool bug in a
schema where it does not belong.

---

## 1. Toolchain gaps

What `gen-*` does and does not carry. All measured, none assumed.

### 1.1 `maximum_cardinality: 0` inverts a prohibition — **DANGEROUS**

A slot declared `maximum_cardinality: 0` — the obvious way to say "this
property must never be supplied" — emits **`sh:maxCount 1`**. The generated
shape *permits one value* of exactly the property the author wrote it to
forbid.

This is the only gap here that makes a shape weaker while looking correct.
A hand-written `sh:maxCount 0` refusing a client-supplied `sessionIri` becomes,
on conversion, a shape that accepts one.

**Do this instead:** omit the slot. `gen-shacl` emits `sh:closed true` with
`sh:ignoredProperties ( rdf:type )` for every class, and pyshacl refuses an
undeclared property with a `ClosedConstraintComponent` violation — verified
against real data, not inferred. Omission is the mechanism; `maximum_cardinality`
is not.

### 1.2 `sh:message` does not survive

Custom SHACL messages are dropped. An annotation named `sh_message` is ignored
silently — no warning, no output.

This matters here more than it might elsewhere. The hand-written mind-pod
shapes attach an operator-facing sentence to each rule ("a PUSH must name its
intent before performing it"), and a refusal that cites a generic
constraint-component violation instead is a worse refusal.

`description:` **does** survive, as both `rdfs:comment` and `sh:description`,
so the *rationale* travels with the shape even though the *message* does not.
Shapes whose value is mostly their messages should stay hand-written.

### 1.3 `gen-typescript` declares enums but does not use them

An enum is emitted as a real TypeScript enum:

```ts
export enum NoteStatus { draft = "draft", published = "published", withdrawn = "withdrawn" };
```

…and then the interface types the slot as a bare string:

```ts
export interface Note { status?: string, … }
```

The enum is generated and unreferenced. A TypeScript consumer gets no
compile-time constraint from it, so the closed vocabulary that SHACL enforces
as `sh:in` is unenforced on the browser side.

### 1.4 `gen-shacl` is byte-unstable and graph-stable

Two runs over an unchanged schema produce textually different Turtle that is
RDF-isomorphic — rdflib orders blank-node property shapes differently per run.

Not a correctness problem, but it decides how artifacts get gated: compare
SHACL as a **graph**, never as bytes. A byte comparison raises drift alarms
that are not drift, and the predictable end of that is a disabled gate.

### 1.5 `gen-python` embeds a timestamp

Output carries `# Generation date: <ISO timestamp>`, so regeneration changes
the file even when the schema has not. `generate_shapes.py` strips that line
at write time. Without stripping, every regeneration churns the diff and the
real change hides among the noise.

### 1.6 `gen-sparql` writes a directory, not stdout

`gen-sparql schema.yaml` prints nothing and exits 0 — it needs `-d <dir>`. It
then emits validation queries (`CHECK_required_*.rq`, `CHECK_permitted_*.rq`,
`CHECK_object_range_*.rq`), which is a different thing from the SPARQL
*templates* [sparqlfun](https://github.com/linkml/sparqlfun) provides. Worth
knowing before reaching for one expecting the other.

### 1.7 Generated SPARQL does not run on Oxigraph — **was DANGEROUS**

`gen-sparql` emits `?subject rdf:type <Class>` while declaring only the
schema's own prefixes. `rdf:` is never declared.

rdflib pre-binds `rdf:`, `rdfs:`, `xsd:` and `owl:`, so the query parses there
and looks fine. Oxigraph — the engine the pod actually runs — binds nothing,
and answers:

```
HTTP 400 — error at 10:20: expected one of Prefix not found
```

This is the sharpest pseudo validation in this document, because the check
that would have missed it is the obvious one. A CI step validating generated
queries with rdflib goes green on queries that can never execute against the
store. The validation appears to work and never runs.

**Closed.** `generate_shapes.py` declares any well-known prefix a query uses
but does not bind, and then parses every query with **pyoxigraph** — the same
engine as a library, not an approximation of it. A prefix that is used,
undeclared and *not* well-known fails the build rather than being guessed at:
inventing a namespace would produce a query that runs and matches nothing,
which is worse than one that refuses to parse.

Verified end to end: the four generated queries returned HTTP 400 from the
pod's Oxigraph before the fix and HTTP 200 after.

### 1.7 Slot URIs are not resolved

`DerivedSchema#uri_for` answers for classes, enums and types, and returns
`nil` for slots. That is downstream of §2.1: the specification's URI
derivation runs through `SafeSnake`, which it never defines, so vv-linkml
declines to invent one.

Consequence: the predicate IRI is the consumer's decision. Assert `slot_uri`
explicitly when a wire vocabulary already exists — this is how a schema adopts
a vocabulary that predates it, and `urn:` CURIEs are distinguished from
absolute IRIs by the prefix map, not by shape.

---

## 2. Specification gaps

What the specification leaves undetermined. `gems/vv-linkml` names each one in
`Unspecified::GAPS`, picks an interpretation, and points the affected code back
at it — so these are queryable rather than folkloric:

```ruby
Vv::Linkml::Unspecified::GAPS.keys
```

| Gap | What is undetermined |
|---|---|
| `safe_functions` | `Safe`, `SafeCamel`, `SafeSnake` decide every derived element URI and are never defined. |
| `pk_undefined` | `PK()` is used twice and defined nowhere; it decides whether a slot is a key. |
| `inlined_as_dict` | Two procedures are written in terms of `s.inlined_as_dict`, which is not a metaslot. |
| `combine_pattern` | The combine table delegates `pattern` to `CombinePattern`, which has no body. |
| `range_intersection` | Combining two ranges yields a set; `range` takes one value. |
| `add_missing_values_target` | `AddMissingValues(s, c)` keys on a metaslot absent from `meta.yaml`. |
| `alias_seeding` | `DerivedSlot` seeds an alias before any combination, changing what later steps see. |
| `apply_slot_usage_pseudocode` | The `ApplySlotUsage` pseudocode rebinds its loop variable. |
| `recommended_check` | The `Recommended` check's fail condition is printed identically to `required`. |
| `deprecated_is_a_string` | Checks compare `deprecated=True`; in `meta.yaml` it is a string. |
| `empty_sections` | Four validation sections are headings with no bodies: rules, uniqueness, classification, inference. |
| `type_instance_operator` | The JSON mapping table uses an operator absent from the grammar. |
| `spec_type_list` | The "Default Types" list gives 14 of the 19 types that exist. |
| `draft_status` | LinkML is a draft, issued by no standards body. |

### 2.1 Most of the metamodel is not normative

```
metaslots:   216   normative: 122
metaclasses:  40   normative:  15
```

`description`, `title`, `comments`, `examples`, `see_also` and `deprecated`
are outside the normative subset. "The metamodel has a slot for it" and "the
specification requires it" are different claims, and a conforming
implementation may ignore the second set entirely.

### 2.2 Five built-in types are missing from the specification's own list

19 types exist in `types.yaml`; `03schemas.md` lists 14, capitalised. Omitted:
`date_or_datetime`, `curie`, `jsonpointer`, `jsonpath`, `sparqlpath`.

The capitalisation is the trap: a schema written `range: Boolean` resolves to
nothing and falls through to `default_range` silently. `Vv::Linkml::Types.miscased`
answers for a given name.

---

## 3. What this costs us, and what is now closed

**Pseudo validation** is the subset that matters: a shape reporting
`conforms: true` over data nothing actually constrained. A missing shape is
visible. A hollow one is an assurance nobody has reason to doubt.

The gaps live upstream and cannot be fixed here. What *can* be fixed is
inheriting one silently, so `tooling/linkml/check_no_pseudo_validation.py`
refuses at generation time — where the author is present — rather than at
validation time, where only a green report is present.

| Gap | Status | How |
|---|---|---|
| `maximum_cardinality: 0` inversion | **CLOSED** | `MAXCARD_ZERO` refuses the schema and names omission as the fix. |
| miscased / unresolvable range | **CLOSED** | `UNRESOLVABLE_RANGE` refuses, and suggests the correctly-cased name. |
| reliance on the empty spec sections | **CLOSED** | `EMPTY_SECTION` refuses `rules`, `unique_keys`, classification rules. |
| unresolved imports (short derivation) | **CLOSED** | `UNRESOLVED_IMPORT` refuses; caught at `SchemaView` construction, which is where it actually raises. |
| a class that constrains nothing | **CLOSED** | `VACUOUS_CLASS` refuses a class whose every slot is optional and unconstrained. |
| a shape that refuses nothing | **CLOSED** | `DOES_NOT_REFUSE` / `NO_TARGETS` probe the artifact with pyshacl: build a node that satisfies every declared property, add one undeclared property, and require refusal. |
| generated SPARQL that cannot run | **CLOSED** | Well-known prefixes declared, then every query parsed by pyoxigraph — the store's own engine. An undeclared prefix that is not well-known fails rather than being guessed. |
| enum unused in TypeScript | **CLOSED** | The artifact is post-processed to type the slot as its enum, so the closed vocabulary is enforced client-side too. |
| `sh:message` dropped | **OPEN** | Not pseudo validation — the constraint holds, the explanation is generic. Message-carrying shapes stay hand-written. |
| byte instability | mitigated | The gate compares graphs. |
| `gen-python` timestamp | mitigated | Stripped at write time. |
| slot URIs unresolved | mitigated | `slot_uri` asserted explicitly against the existing `urn:mm:vocab/pod#` vocabulary. |
| draft status | accepted | The pin is load-bearing; `linkml==1.11.1` is exact, and a bump moves artifacts without any schema changing. |

### Why the refusal probe satisfies the shape first

The obvious probe — a bare node of the target class carrying an undeclared
property — passes for the wrong reason. It is missing every required slot, so
a shape whose `sh:closed` had been *removed* still refuses it, on `minCount`.
The check would then report success while proving nothing about closedness;
that was observed, not theorised, when the plant for it failed to fire.

The probe therefore populates every declared property first, asserts that node
**conforms**, and only then adds the undeclared property and requires refusal.
If the clean node does not conform, the probe reports `CANNOT_PROVE` rather
than claiming a result — an unprovable shape is not a passing one.

## 4. Re-measuring

This document rots the moment the pin moves. To re-measure after a version
bump:

```bash
.venv/bin/pip install -r tooling/linkml/requirements.txt
ruby -e '$LOAD_PATH.unshift "gems/vv-linkml/lib"; require "vv/linkml"; p Vv::Linkml.census'
.venv/bin/python tooling/linkml/generate_shapes.py --check
```

`census` reports the metamodel version the Ruby model is built against; if it
disagrees with the installed generators, the two halves are on different
metamodels and the counts in §2.1 are stale. `--check` fails if generator
output moved — which after a version bump is the expected result and the
reason artifacts record their generator version.
