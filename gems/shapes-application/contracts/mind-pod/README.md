# mind-pod application contract

Slot for this repository's application-owned request/response shapes
(`NoteCreateEffectShape`, `SessionOpenEffectShape`, `JourneyListPullShape`,
`ConceptPutEffectShape`, and the rest of mind-pod's accepted contracts).

Holds mind-pod operation contracts (note/session + P9/P11 request/response
shapes). Protocol vocabulary (`JourneyShape`, `ConceptShape`, …) lives in
`shapes-level-8`.

## What is actually constrained here

Measured 2026-09-09. The counts matter because a shape file that declares
names without constraints reads exactly like one that constrains something.

| file | node shapes | with `sh:property` | targeted |
|---|---|---|---|
| `profile-1-cyborg-channel.ttl` | 4 | 4 | 0 |
| `profile-4-durable-execution.ttl` | 2 | 2 | 0 |
| `profile-9-ghis.ttl` | 26 | 25 | 0 |
| **`profile-11-meaning.ttl`** | **32** | **0** | **0** |

**`profile-11-meaning.ttl` is stubs.** Thirty-two shapes, each `sh:closed true`
with no `sh:property` and no `sh:targetClass` — 160 triples, zero `sh:in`, zero
constraints. Its header now says so; it previously claimed "the five maturity
dimensions are `sh:in` enumerations so conformance stays decidable", describing
the file it was meant to be. Correcting it moved the file's digest, which
`tooling/shacl/check_shape_digests.py` governs byte-for-byte under ADR 0044,
so the baseline was rewritten with `--write` and the diff audited: every
changed line was that one digest, and nothing else moved.

**Nothing is silently ungated by that.** `RailsOsiLevel8::Grounding` does not
execute this TTL. It hand-mirrors each shape's allow-list in a `case`, and its
`else` branch fails closed — a P11 operation gets "no runtime closed-shape
check is implemented … refusing rather than validating nothing". P11 is
unimplemented and refused, not permissive.

**None of these files self-target**, so a SHACL processor handed them validates
nothing and returns `conforms: true` for any graph, including an empty one.
That is correct for their intended consumer, which selects shapes by name and
supplies the focus node. It is a trap for any other consumer, and it is the
reason generated shapes carry `sh:targetClass` and `sh:closed`
([ADR 0069](../../../../docs/adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md)).

**Do not confuse `profile-11-meaning.ttl` with the file of the same name in
`shapes-level-8/bundles/`.** They share zero shape names. The bundle holds the
domain model — `ConceptShape`, `DefinitionRevisionShape`, and fourteen more,
targeted and constrained. This directory holds per-operation request shapes.
