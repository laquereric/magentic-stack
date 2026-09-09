# LinkML — research note

The note this gem was built from. Every fact below names the file it came from
and the SHA-256 of that file as downloaded. Nothing here was typed from memory
and nothing was taken from a summary of the specification.

## Sources, as read

Downloaded **2026-09-08**.

| File | Source | SHA-256 | Bytes |
|---|---|---|---|
| `meta.yaml` | `raw.githubusercontent.com/linkml/linkml-model/main/linkml_model/model/schema/meta.yaml` | `7f9e39fb18ab4bc034c00f37cd291fbb87f8fb1e2f36f43e566918bd56b96673` | 102,037 |
| `types.yaml` | `.../linkml_model/model/schema/types.yaml` | `1c79b264397bec0eadb404d22e9b163458f1b889809b3b482ecc39c98743fe00` | 7,296 |
| `00preamble.md` | `.../linkml_model/model/docs/specification/00preamble.md` | `7a4b902ba6e371e727e7b08d31762d234f096dd278b77a6d3c7e3d33044a87ad` | 1,291 |
| `02instances.md` | `.../specification/02instances.md` | `0437b74f4e1577ffedc787cffa52ea69f4469b77850d9de6172d93a93f079e95` | 11,737 |
| `03schemas.md` | `.../specification/03schemas.md` | `439e5addb75d0c2c54f21f57730202f6c592ba5feebf24903026927e15c3d811` | 43,741 |
| `04derived-schemas.md` | `.../specification/04derived-schemas.md` | `539b17d17b68c7220833d7dc0fc1840d45c12452e6b50991850872b06f4f6472` | 20,132 |
| `05validation.md` | `.../specification/05validation.md` | `711b447e61db8f8ffa403b24993d56f523017e63b639a09798dbb7f17355bab9` | 15,456 |
| `06mapping.md` | `.../specification/06mapping.md` | `a611c7ed9e425c3e74f700e231f21b7b057939e4bf765ef895991afc056e3ba8` | 14,454 |

`meta.yaml` declares `metamodel_version: 1.11.0`. The latest `linkml-model`
release at read time is `v1.11.0` (2026-05-14); the latest `linkml` reference
implementation release is `v1.11.1` (2026-05-20). The `meta.yaml` commit read
here is `35c91fb01382` (2026-08-25), i.e. *ahead of* the tagged release.

## The status of the specification

`00preamble.md`, verbatim:

> ### Status of this specification
>
> This is a draft specification open from comments to all.

LinkML is not a standard issued by a standards body. It is a draft
specification, authored by Chris Mungall (LBNL) and Harold Solbrig (JHU),
alongside a reference implementation. The gem says so in
`Vv::Linkml::SPEC[:status]` rather than in a footnote, because a draft borrowing
the settled authority of a Recommendation is the specific error that models of
standards make.

## Most of the metamodel is outside the specification

`03schemas.md` §"The LinkML Metamodel":

> This specification specifies the *normative elements* necessary to specify the
> behavior of LinkML schemas. Schemas may have additional elements provided in
> the metamodel. […] The subset of the metamodel that corresponds to the
> specification is called the SpecificationProfile.

Counted from `meta.yaml` by membership in `in_subset: [SpecificationSubset]`:

- **122 of 216 metaslots** are in the specification subset. 94 are not.
- **15 of 40 metaclasses** are in the specification subset. 25 are not.

So roughly **44% of the metamodel carries no normative weight**. `description`,
`title`, `comments`, `examples`, `see_also`, `deprecated` and the rest are real
metaslots that real schemas use, and a conforming implementation is entitled to
ignore them. `Vv::Linkml::Metamodel.normative?` answers this per metaslot, and
the answer is the reason the gem does not treat "in the metamodel" and "the spec
says so" as the same claim.

The 15 specification metaclasses are: `schema_definition`, `type_definition`,
`subset_definition`, `enum_definition`, `enum_binding`, `match_query`,
`reachability_query`, `slot_definition`, `class_definition`, `class_rule`,
`setting`, `prefix`, `permissible_value`, `unique_key`, `type_mapping`.

## The built-in types: 19, not 14

`types.yaml` defines **19** types. `03schemas.md` §"Default Types" lists **14**,
and lists them under capitalised names:

> - Boolean (Bool) - A binary (true or false) value
> - Date (XSDDate) …

Two problems with that list, both checkable against `types.yaml`:

1. **Five types are missing from it**: `curie`, `date_or_datetime`,
   `jsonpointer`, `jsonpath`, `sparqlpath`.
2. **The names as printed are not usable.** `types.yaml` attaches a note to
   every single type: *"If you are authoring schemas in LinkML YAML, the type is
   referenced with the lower case …"*. A schema that writes `range: Boolean`
   does not resolve to the built-in type; it resolves to nothing, and
   `default_range` silently takes over. `Vv::Linkml::Types` is keyed by the
   lowercase names from `types.yaml`, and `Types.miscased` names the trap.

`type_definition` also has a name/serialisation split: the metaslot is
`type_uri`, and its `alias` is `uri`. In YAML you write `uri:` under a type; the
metamodel calls it `type_uri`. `03schemas.md`'s normative table lists it as
`type_uri`, which is the metaslot name, not the key you write.

The same split hits `schema_definition`: the metaslot is `slot_definitions`,
`alias: slots`. `meta.yaml` says so directly:

> note the formal name of this element is slot_definitions, but it has alias
> slots, which is the canonical form used in yaml/json serializes of schemas.

## Derivation is the specified part

`04derived-schemas.md` is the substance of LinkML: an asserted schema *m* is
turned into a derived schema *m*ᴰ by a stated procedure. It defines the
functions **L** (normalize-to-list), **K** (identifier value), **URI**/**CURIE**,
**Resolve**, **C** (closure), **P** (parents = `is_a` ∪ `mixins` ∪ `{Any}`),
**A**/**A\*** (ancestors), **I** (imports closure), **ApplicableSlots**, and the
algorithms **CombineSlots**, **CombineSchemas** and **DerivedSlot**.

This is what `Vv::Linkml::Derivation` implements, and the metaslot-combination
precedence table is transcribed rather than paraphrased — the row order is
load-bearing, and `range` is matched *by name* before the generic `multivalued`
and `boolean` rows.

Two things the derivation procedure gets right that intuition gets wrong:

**Only inheritable metaslots propagate along the slot hierarchy.** `DerivedSlot`
walks `A(s)` but copies only metaslots where `ms.inheritable`. In `meta.yaml`
that flag is spelled `inherited: true`, and exactly **40** of the 216 metaslots
carry it. `description` is not one of them. A slot that inherits from a
documented parent does not inherit the documentation.

**Mixins outrank `is_a`.** `ApplySlotUsage` recurses over
`L(c.mixins) ∪ L(c.is_a)` in that order. Most object-oriented intuition puts the
primary parent first.

## What the specification does not say

These are gaps in the document as read, not opinions about it. Each is a
`Vv::Linkml::Unspecified::GAPS` entry, and each has an interpretation the gem
applies and names.

**Metaslots the spec's own procedures use that do not exist in the metamodel.**
`04derived-schemas.md`'s `AddMissingValues` table keys on `s.inlined_as_dict`,
and `06mapping.md`'s entire collection-form decision procedure is written in
terms of `s.inlined_as_dict` and `s.inlined_as_expanded_dict`. Neither slot is
in `meta.yaml`. The metamodel has `inlined`, `inlined_as_list` and
`inlined_as_simple_dict`. An implementation reading part 6 literally has nothing
to read.

**`PK()` is used and never defined.** It appears twice —
`04derived-schemas.md` line 348 and `06mapping.md` line 234 — with no
definition anywhere in the specification.

**`Safe`, `SafeCamel` and `SafeSnake` are used and never defined.** All three
appear only in the Element URI table of `04derived-schemas.md`. They determine
every derived `class_uri` and `slot_uri` in every LinkML schema, and the
specification does not say what they compute.

**`CombinePattern` is used and never defined.** `04derived-schemas.md`'s
combination table delegates `pattern` to it.

**Whole sections are empty.** In `05validation.md`: `### Rules`,
`### Uniqueness checks`, `### Classification Rule evaluation` and
`## Inference of new values` have headings and no body. In
`04derived-schemas.md`: `### Rule: Derived Permissible Values` reads, in full,
`TODO`.

**`range` combination is set-valued for a single-valued metaslot.**
`CombineSlotsMetaslots` for `range` yields `A*(r1) ∩ A*(r2)` — an intersection
of ancestor sets — but `range` is `0..1`. The spec does not say how to pick one.

**Two rows of the validation table appear to be transcription errors.** The
`Recommended` check's fail condition is printed as `<slot>.required=True`, the
same condition as the `Required` check above it. And the deprecation checks
compare `deprecated=True`, but `deprecated` in `meta.yaml` has range `string`,
not `boolean`.

**`06mapping.md`'s translation table uses `&` for type instances.** Rows read
`<TypeDefinitionName>&<StringValue>`; part 2's grammar is
`InstanceOfType := TypeDefinitionName '^' AtomicValue`. `&` is the reference
operator.

None of this makes LinkML unusable — the reference implementation resolves all
of it. It makes the difference between "LinkML says" and "the Python
implementation does" a real difference, and this gem refuses to blur it.

## Names are unique across all element types

`02instances.md`, on `ElementName`:

> Names MUST NOT be shared across definition types

A class named `Person` and an enum named `Person` are not a namespacing
question; they are invalid. `Vv::Linkml::Schema` raises `NameCollision` at load
rather than resolving the later one and moving on.

## The single normative default

`04derived-schemas.md` §"Rule: Populate Schema Metadata":

> if `m'.default_range` is not set, set it to `string`.

Combined with `range`'s `ifabsent: default_range` in `meta.yaml`, this is the
whole default chain: a slot with no `range` gets the schema's `default_range`,
and a schema with no `default_range` gets `string`. This is applied per
*imported* schema, not once at the top — each `m'` in `I(m)` gets its own.
