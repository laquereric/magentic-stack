# The shape tool flow

LinkML is the source of truth for shapes. SHACL, TypeScript and Python are
reified from it. Shapes are morphed by dev and only read by prod.

This directory is the reference implementation of that flow. It is written to
be **copied**: the CPCP ecosystem fragments the moment two repos generate
shapes differently, and a shape that means one thing in the contract repo and
another in a consumer is worse than no shape.

Governed by [ADR 0069](../../docs/adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md).

## The flow

```
  LinkML schema  ──gen-shacl───────▶  .shacl.ttl   ┐
  (source of     ──gen-typescript──▶  .ts          ├─▶ MANIFEST.json ─▶ consumers
   truth)        ──gen-python──────▶  .py          ┘
       │                                                     ▲
       └─────────────────── published alongside ─────────────┘
```

1. **Author** one LinkML schema. It is the only place the shape is asserted.
2. **Register** it in `sources.json` with the artifacts it reifies into.
3. **Generate** with `.venv/bin/python tooling/linkml/generate_shapes.py`.
4. **Publish** the source *and* the artifacts together. `MANIFEST.json` ties
   them: source path, source SHA-256, every artifact and its SHA-256, and the
   generator version.
5. **Gate** with `check_shape_artifacts.py`, run by `bin/sweep`.

## What a conforming implementation must hold

A repo adopting this flow is claiming five things. Each has a reason that was
paid for.

**One source per shape.** If a shape is asserted in a schema *and* in
hand-written SHACL, the two drift and nothing says which is right.

**A provenance header on every artifact** naming source path, source SHA-256
and generator version. Generator output moves with the generator; without the
version recorded, "the artifact changed" and "the schema changed" are
indistinguishable.

**Publish source with artifacts.** An artifact alone cannot be re-derived,
checked, or extended by a consumer. A schema alone makes every consumer run a
Python toolchain. Publishing both is what lets a Ruby or JavaScript consumer
read bytes while a schema-aware one re-derives.

**Compare SHACL as a graph, not as bytes.** `gen-shacl` is byte-unstable and
graph-stable: rdflib orders blank-node property shapes differently per run, so
two runs over an unchanged schema differ textually while being RDF-isomorphic.
A byte comparison here produces drift alarms that are not drift, and the
predictable end of that is someone disabling the gate.

**Prod does not generate.** No runtime imports linkml, shells out to `gen-*`,
or installs the toolchain. A container that generates its own shapes has no
fixed answer to "what shape was enforced when this request was refused."

**No pseudo validation.** A schema that would generate a hollow shape is
refused at generation time by `check_no_pseudo_validation.py`, and every
generated shape is probed with pyshacl to prove it actually refuses
something. `conforms: true` has to mean a test ran, not that a constraint was
absent — see [LinkMlGaps.md §3](../../docs/architecture/LinkMlGaps.md).

## Fidelity — read this before converting a hand-written shape

Measured 2026-09-09 against linkml 1.11.1. The full account, including the
specification gaps underneath these, is
[`docs/architecture/LinkMlGaps.md`](../../docs/architecture/LinkMlGaps.md).

| Construct | Survives? |
|---|---|
| datatype, cardinality, enums (`sh:in`) | yes |
| `sh:closed true` + `sh:ignoredProperties` | yes, emitted automatically |
| `description:` → `rdfs:comment` + `sh:description` | yes |
| `sh:message` | **no — silently dropped** |
| a prohibition | only by **omitting** the slot |

Two of these will cost you if you skip them:

**`sh:message` does not survive.** An annotation named `sh_message` is
ignored. Hand-written shapes that attach an operator-facing sentence to each
rule lose those sentences on conversion. Shapes whose value is mostly their
messages should stay hand-written until this is addressed upstream.

**Never write `maximum_cardinality: 0` to forbid a property.** It emits
`sh:maxCount 1` — it *permits one value* of exactly the property it was
written to forbid. Omit the slot instead and let `sh:closed` refuse it;
verified with pyshacl, which reports a `ClosedConstraintComponent` violation.

## Adopting this in another repo

Copy `requirements.txt`, `generate_shapes.py`, `check_shape_artifacts.py` and
`plant_shape_artifacts.py`. Point `sources.json` at your schemas. Pin the same
linkml version as the contract repo — a different generator version is a
different artifact, and matching pins is most of what "same tool flow" means
in practice.

Do **not** copy the artifacts. Copy the source and regenerate, or consume the
published artifacts and verify them against `MANIFEST.json`. Copying artifacts
without their source is how a fork starts.

## Not yet in the shape gems

Artifacts land in `generated/`, not under `gems/shapes-*/`. Every NodeShape
inside the governed TTL trees must be registered in six places — binding
manifest, IRI namespace baseline, digest baseline, quarantine inventory,
resolution manifest, in-scope count. Dropping a generated shape into
`contracts/mind-pod/` failed all six at once. Promotion is a deliberate
governance act; see ADR 0069's consequences.
