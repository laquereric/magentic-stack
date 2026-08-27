# ACIA conformance gap: the implementations against the Profile 9 specification

**2026-08-26.** Written after a framing correction: Profile 9 specifies
implementation-independent TYPES; `Mmg::Acia` and `RailsOsiLevel8::Profile9::Acia`
implement that interface. The implementation depends on the specification, not
the other way round.

That reframing invalidates how I had been describing this. ADR 0035 calls it a
*convergence of two vocabularies* and asks *which vocabulary survives*. There is
no contest to settle: `https://w3id.org/cpcp/osi8/ux#` is the specification and
both are implementations that owe it conformance. The work is a **conformance
gap per implementation**, not a merge.

## Where the specification actually is

`gems/osi-level-8-profiles/profile-9-governed-human-interaction-surface/shapes/osi-level-8-profile-9-ghis.shacl.ttl`

228 lines, 17 NodeShapes, 209 `ux:` terms, **13 closed enumerations**. It is
normative, implementation-independent, and it was there the whole time.

## Finding 1 - the values agree; nothing has drifted

| enumeration | spec | rails-osi-level-8 | mmg-acia seeds |
|---|---|---|---|
| semanticRole | 14 | match | match |
| contentRole | 12 | match | match |
| layoutKind | 7 | match | match |
| layoutArity | 4 | match | match |
| behaviorKind | 8 | match | match |
| componentKind | 19 | match | **missing** |
| variantName | 9 | match | **missing** |
| eventKind | 4 | **missing** | **missing** |
| ledgerPlacement | 3 | **missing** | **missing** |
| emotion | 6 | **missing** | **missing** |
| overridePolicy | 3 | **missing** | **missing** |
| relation | 4 | **missing** | **missing** |
| tokenCategory | 5 | **missing** | **missing** |

Every token set that exists in an implementation matches the spec exactly -- no
value drift in either direction. The gap is **coverage**, not disagreement.

mmg-acia models 5 of 13. I described those five as "the five SLT dimensions" and
scoped `componentKind` out as "a sixth axis, not one of the five". The spec has
thirteen; five was the shape of what Profile 9's Ruby happened to expose, not the
shape of the specification.

## Finding 2 - I minted a parallel namespace

The spec's dimension values are **IRIs in one flat namespace**:

    sh:in ( ux:landmark ux:heading ux:list ... )        # ux:heading

mmg-acia mints its own, per-dimension:

    urn:mm:vocab/acia#semanticRole/heading

Those agree in spelling and in nothing else. A consumer resolving `ux:heading`
finds nothing we publish. This is a third vocabulary, not a conformance.

It also invalidates the argument I used to justify **five tables**: that `table`
is both a `semanticRole` and a `layoutKind`, so one table keyed by token would
"collapse two things into one row". The spec uses **one resource**, `ux:table`,
in both `sh:in` lists -- constrained by which property it appears on. Under the
specification they *are* one thing, and my reasoning was backwards.

## Finding 3 - both implementations flatten a nested type

`ux:ComponentShape` requires `ux:slt min1 max1 sh:class ux:SLTTuple` -- the tuple
is its own node, and `ux:SLTTupleShape` is `sh:closed`. Same for `props`
(`TypedProps`) and `variant` (`VariantSelection`).

- Profile 9's **JSON validator conforms**: `NODE_KEYS` nests `slt`, `props`,
  `variant`, `slots`, `children`.
- Profile 9's **RDF projection does not**: it flattens the tuple into five
  predicates on the node. No `SLTTuple` node is ever emitted.
- **mmg-acia does not**: it flattens the same way, because I conformed it to the
  projection rather than to the spec.

So the divergence is in the RDF mapping, not the document model -- and I
propagated it into a second implementation.

## Finding 4 - GovernedFields are absent from both RDF projections

`ux:GovernedFieldsShape` requires `cid`, `created`, `digest`, `profileId`,
`wasGeneratedBy` and `ledgerPlacement` on every governed node. Neither projection
emits any of them per node. Profile 9 carries a document-level `aciaDigest`;
mmg-acia carries none.

## What I got right, and why

`rails-osi-level-8` takes **no dependency on mmg-acia** -- the IRI form is a
literal in `Projection.slt_iri`. Under this framing that is correct and should
stay: a specification-side implementation must not depend on another
implementation.

## What I got wrong

I named `db/seeds/acia_dimensions.yml` the **authority** and checked Profile 9's
Ruby constants against it. Both are implementations. `check-slt-alignment`
therefore compares two implementations to each other: they can agree perfectly
and both drift from the specification, and the gate would stay green. It should
compare each implementation to the TTL.

## Finding 5 - the specification is inconsistent with itself

Eleven enumerations are IRI-valued:

    sh:property [ sh:path ux:semanticRole ; sh:in ( ux:landmark ux:heading ... ) ]

Two are string-literal-valued:

    sh:property [ sh:path ux:relation ;       sh:in ( "contains" "narrows" ... ) ]
    sh:property [ sh:path ux:overridePolicy ; sh:in ( "none" "escalate" ... ) ]

So "the spec models a dimension value as a resource" is true of 11 of 13, not of
all. Worth settling in the spec before implementations copy the split.

This surfaced because a first-cut extractor read only the IRI form and returned an
EMPTY list for the other two -- 7 of 98 terms vanished with no error. The
generator now reads both and **fails closed** when an enumeration parses to
nothing, since a form it does not understand is a reason to stop rather than to
emit a vocabulary quietly missing a type.

## Measured, not argued (update)

Findings 1-5 above were hand-analysis. The projection's output is now run through
**pySHACL against the normative shapes**, which is the only reading that counts.

After adopting `ux:` and nesting the tuple: **12 violations, none of them on the
tuple.** The SLT tuple conforms to its closed shape exactly -- 5 dimension terms,
`responsiveSignature`, `tokenSignature`.

The remainder falls into three classes:

| class | n | what it means |
|---|---|---|
| closed-shape | 4 | the projection emits a predicate the shape has no slot for |
| missing required | 4 | a required property is not emitted |
| value not in enumeration | 2 | a term is emitted outside the specified list |

**The closed-shape four are a specification gap, not an implementation bug.**
`ux:position`, `ux:inDocument` and the prop table carry real information --
sibling order, document membership, a queryable prop surface -- and
`ux:ComponentShape` is `sh:closed` with no slot for any of them. Conforming by
deletion would lose the ordering of a rendered tree. That belongs in the spec, or
as a recorded exception; it should not be resolved by quietly dropping data.

## Ordered remedy

1. **Repoint the checker at the specification.** Parse the `sh:in` lists out of
   the normative TTL and compare each implementation against them, covering all
   13 enumerations rather than 5. Cheapest step, catches the most, changes no
   runtime behaviour.
2. **Decide the namespace.** Either adopt `ux:` as the dimension IRI, or state
   why a `urn:mm:` alias exists and publish the mapping. Adopting `ux:` costs a
   rewrite of the 2,855 triples normalized earlier -- the same in-place migration,
   already rehearsed.
3. **Decide flatten-vs-nest for the RDF mapping**, once, and apply it to both
   projections. If the spec's nesting stands, both need `SLTTuple` nodes.
4. **Cover the remaining enumerations** where an implementation needs them.
5. **GovernedFields** per node, or an explicit recorded exception.

Steps 2 and 3 are specification-conformance decisions with live production
consumers on both sides. They belong to the owner, not to me.

## Effect on ADR 0035

Its question -- *which vocabulary survives* -- should be withdrawn. The successor
question is *how far does each implementation conform, and what is deliberately
excepted*. 0035 stays `proposed` until that is recorded.
