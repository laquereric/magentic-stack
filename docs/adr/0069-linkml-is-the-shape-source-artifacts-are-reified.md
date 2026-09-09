---
id: "0069"
title: LinkML is the shape source; SHACL, TypeScript and Python are reified artifacts
status: accepted
date: 2026-09-09
subject_kind: protocol
subject: shapes
components: [shapes-application, shapes-level-8, back, mind, front]
paths:
  - tooling/linkml/sources.json
  - tooling/linkml/generate_shapes.py
  - gems/shapes-application/contracts/mind-pod/linkml/pod-note.yaml
enforced_by:
  - tooling/linkml/check_shape_artifacts.py
  - tooling/linkml/plant_shape_artifacts.py
supersedes: null
superseded_by: null
---

# LinkML is the shape source

## Decision

1. **A shape is authored once, in LinkML.** The shape container owns the
   schema; `tooling/linkml/sources.json` is the register of which schemas
   exist and what each one reifies into.
2. **SHACL, TypeScript and Python are generated artifacts**, produced by the
   upstream LinkML generators (`gen-shacl`, `gen-typescript`, `gen-python`)
   pinned in `tooling/linkml/requirements.txt`. Each artifact carries a
   provenance header naming its source path, the source SHA-256, and the
   generator version.
3. **Shapes are morphed by dev and only read by prod.** `generate_shapes.py`
   runs in development. Nothing under `runtimes/` imports linkml, shells out
   to a `gen-*` binary, or installs the toolchain into an image. Production
   reads the committed artifacts.
4. **RDF and SHACL remain what goes on the wire.** This changes where shapes
   are written, not what BACK enforces or what the store holds. ADR 0045
   still holds: CPCP is the shape container.
5. **Authoring and generation are Python. Enforcement is not.** LinkML and the
   Python toolchain are where a shape is defined and reified. The live refusal
   path does **not** move: `Grounding.closed_shape_violations` still refuses a
   request in Ruby, reading the generated TTL. `ROLE_SHAPE.md`'s "**This does
   not move**" stands, and this ADR does not touch it.
6. **A standards document publishes the source AND the artifacts.**
   `generated/MANIFEST.json` ties them — source path, source SHA-256, each
   artifact and its SHA-256, generator version. Artifacts without their source
   cannot be re-derived or extended; a source without artifacts makes every
   consumer run a Python toolchain. The ecosystem adopts one flow
   (`tooling/linkml/README.md`) because two flows are how the same shape comes
   to mean two things.

## What this deprecates

`Vv::Graph::Linkml.shapes` and `.load_shapes` — the Ruby SHACL derivation —
are deprecated. They warn once per process and stay one release.

They were added earlier the same day this ADR was written, and they are the
weaker of the two derivations: upstream `gen-shacl` emits `sh:closed true`
with `sh:ignoredProperties`, which the Ruby adapter never did, and closed
shapes are the discipline OSI-8 rests on. Two derivations of one schema is the
fragmentation the single-source rule exists to prevent, so the newer one goes.

`Vv::Graph::Linkml.field` and `Storable.triples_from_linkml` are **not**
deprecated. They resolve a slot at runtime rather than deriving a shape, and
no generated artifact answers "what IRI does this model's field carry" today.

## Why prod must not generate

A container that generates its own shapes has no fixed answer to "what shape
was enforced when this request was refused". The artifact would depend on the
generator version present at boot, which is a build-time fact leaking into a
request path. Generation is also the one step that can fail in a way that
silently *weakens* a shape rather than breaking it — see the fidelity note
below. `check_shape_artifacts.py` scans `runtimes/` for the three shapes that
failure takes: an import, a generator invocation, a toolchain install.

## Fidelity: what the generator does and does not carry

Measured 2026-09-09 against linkml 1.11.1.

**Carried.** Datatype, cardinality, enums as `sh:in`, and `sh:closed true`
with `sh:ignoredProperties ( rdf:type )` — the closed-world discipline OSI-8
depends on, which hand-written shapes had to remember to add. `description:`
survives as both `rdfs:comment` and `sh:description`, so the reasoning
travels with the shape.

**Not carried.** `sh:message` is dropped. An annotation named `sh_message` is
silently ignored, so the operator-facing sentence a hand-written shape
attaches to each rule does not survive generation. Shapes whose value is
largely in their messages should stay hand-written until this is addressed.

**A trap.** A prohibition MUST be expressed by omitting the slot and relying
on `sh:closed`, never by `maximum_cardinality: 0`. The latter emits
`sh:maxCount 1` — it *permits one value* of exactly the property it was
written to forbid. This was measured, not assumed: pyshacl refuses an
undeclared property with a `ClosedConstraintComponent` violation, which is
the mechanism that makes omission work.

## Comparison is by graph, not by bytes

`gen-shacl` is byte-unstable and graph-stable: rdflib serialises blank-node
property shapes in a different order per run, and two runs over an unchanged
schema are RDF-isomorphic. Artifacts are therefore committed as readable
Turtle and compared as graphs. `gen-python` and `gen-typescript` are
byte-stable once the `Generation date` line is dropped, which the generator
does at write time so that regeneration does not churn every diff.

## Consequences

- Generated artifacts currently land in `tooling/linkml/generated/`, **not**
  in the shape gems. Every NodeShape inside the governed TTL trees must be
  registered in six places (binding manifest, IRI namespace baseline, digest
  baseline, quarantine inventory, resolution manifest, in-scope count).
  Dropping a generated shape into `contracts/mind-pod/` failed all six at
  once. Promoting a generated shape into the governed tree is a separate,
  deliberate act — `capture_shape_baseline.py` re-freezes the baseline across
  every shape, which would also absorb any unrelated drift standing at the
  time.
- The pinned linkml version is load-bearing. Generator output moves with the
  generator, so a bump changes artifacts without any schema changing; the
  provenance header records the version so the two causes stay tellable
  apart.
- `gems/vv-linkml` is unaffected and stays zero-dependency. It models the
  draft specification; it does not generate, and the Ruby adapter
  (`Vv::Graph::Linkml`) remains the runtime path for deriving shapes in
  process.
