# vv-linkml

The Linked Data Modeling Language as a domain model: its metamodel, the
derivation procedure that turns an asserted schema into a derived one, the
validation checks the specification actually tabulates, and — explicitly — the
line between what the specification states and what an implementation supplies.

Built from [`docs/LinkedDataModelingLanguage.md`](docs/LinkedDataModelingLanguage.md),
the research note recording which source each fact came from and which source got
it wrong.

```ruby
schema = Vv::Linkml.load_file("person.yaml")
derived = Vv::Linkml.derive(schema)

derived.complete?                                  # => true
derived.slots_for("Person")["age_in_years"].range  # => "integer"

report = Vv::Linkml.validate({ "id" => "P1", "age_in_years" => "forty" },
                             schema: schema, target: "Person")
report.conclusive?   # => true
report.valid?        # => false
```

Ruby ≥ 3.2. No runtime dependencies.

## LinkML is a draft

```ruby
Vv::Linkml::SPEC[:status]
# => "This is a draft specification open from comments to all."
```

That is `00preamble.md` verbatim. LinkML is not issued by a standards body.
There is a specification, a metamodel and a reference implementation, and the
first of those has no Recommendation-equivalent status.

## Most of the metamodel is not normative

```ruby
Vv::Linkml.census
# => {metaslots: 216, normative_metaslots: 122, inheritable_metaslots: 40,
#     metaclasses: 40, normative_metaclasses: 15, metamodel_version: "1.11.0", ...}

Vv::Linkml::Metamodel.normative?("range")        # => true
Vv::Linkml::Metamodel.normative?("description")  # => false
```

`03schemas.md` says the specification covers only "the *normative elements*
necessary to specify the behavior of LinkML schemas", and `meta.yaml` marks that
subset. Counted: **122 of 216 metaslots and 15 of 40 metaclasses**. `description`,
`title`, `comments`, `examples`, `see_also` and `deprecated` are outside it — real
metaslots that real schemas use, which a conforming implementation may ignore.

So "the metamodel has a slot for it" and "the specification requires it" are two
different claims. This gem never collapses them.

## There are 19 built-in types, and the specification lists 14

```ruby
Vv::Linkml::Types.names.size              # => 19
Vv::Linkml::Types.omitted_from_spec_list
# => ["date_or_datetime", "curie", "jsonpointer", "jsonpath", "sparqlpath"]
```

`03schemas.md`'s "Default Types" section is short by five, and prints the rest
capitalised — `Boolean`, `Date`, `Datetime`. Those names do not work.
`types.yaml` attaches the same note to every type: *"If you are authoring schemas
in LinkML YAML, the type is referenced with the lower case …"*.

The failure is silent. An unresolvable range is not an error in LinkML — it falls
through to `default_range`, which for a schema that never set one is `string`. A
slot you meant as a boolean quietly validates strings.

```ruby
Vv::Linkml::Types.miscased("Boolean")   # => "boolean"
schema.unresolvable_ranges              # => [["is_active", "Boolean", "boolean"]]
```

## Every induced slot says where its values came from

`DerivedSlot(m, s, c)` combines the class's `slot_usage`, its `attributes`, every
ancestor's, the top-level slot, and that slot's ancestry — five places a value
can be written, plus two defaults. So the answer to "why is this required?" is a
field, not an archaeology exercise:

```ruby
age = derived.slot_for("Person", "age_in_years")
age.provenance
# => {"range" => :top_level_slot, "required" => :slot_usage, "alias" => :seeded}

# `asserted?` separates a written value from a defaulted one:
age.asserted?("range")                                  # => true  — someone wrote it
derived.slot_for("Note", "body").asserted?("range")     # => false — the
                                                        # default_range chain supplied it
```

Two behaviours worth knowing, both specified and both counter-intuitive:

**Only the 40 inheritable metaslots propagate along the slot hierarchy.** A slot
with `is_a: documented_parent` inherits its `range` and its `required`, and none
of its `description`.

**Mixins outrank `is_a`.** `ApplySlotUsage` visits `L(c.mixins) ∪ L(c.is_a)` in
that order.

## Derived URIs are marked as derived

```ruby
uri = derived.uri_for("Person")
uri.curie        # => "person:Person"
uri.uri          # => "https://w3id.org/linkml/examples/person/Person"
uri.derived?     # => true  — the schema did not write this
uri.resolvable?  # => true
```

`resolvable?` is the one that earns its keep. When `default_prefix` names no
entry in the prefix map, the derived CURIE still exists and still looks
plausible, and it expands to nothing. `derive` reports that as a gap rather than
emitting an IRI that parses and does not resolve.

## `valid?` is not `conforms`

```ruby
report.valid?       # => true
report.conclusive?  # => false
report.skipped
# => ["class Order declares 2 rule(s); 05validation.md's \"Rules\" section is a
#     heading with no content (Unspecified::GAPS[:empty_sections])"]
```

Four sections of `05validation.md` — Rules, Uniqueness checks, Classification
Rule evaluation, Inference of new values — are headings with no bodies. So are
`04derived-schemas.md`'s Derived Permissible Values, which reads `TODO`.

A schema whose real constraints live in `rules` gets an empty problem list from
any implementation of the tabulated checks. `valid? && !conclusive?` is the
result that looks like a pass and is a pass over a subset, and `skipped` names
the subset.

## What the specification does not say

```ruby
Vv::Linkml.gaps.size                              # => 14
Vv::Linkml::Unspecified[:pk_undefined].what
# => "`PK()` is used twice and defined nowhere in the specification. It decides
#     whether a slot is inlined and how a generated class is named."
```

Fourteen entries, each with a file-and-line location, the claim, and the
interpretation this gem applies. The ones that bite:

| Gap | What |
|---|---|
| `inlined_as_dict` | Part 6's entire collection-form procedure is written against `inlined_as_dict` and `inlined_as_expanded_dict`. Neither is in `meta.yaml`. |
| `pk_undefined` | `PK()` used twice, defined nowhere. |
| `safe_functions` | `Safe`, `SafeCamel`, `SafeSnake` decide every derived `class_uri` and `slot_uri` in every LinkML schema, and are never defined. |
| `combine_pattern` | `CombinePattern(v1,v2)` used by the combination table, defined nowhere. |
| `range_intersection` | Combining ranges yields `A*(r1) ∩ A*(r2)`, a set, for a metaslot with cardinality `0..1`. No rule for choosing. |
| `alias_seeding` | `DerivedSlot`'s pseudocode makes a declared `alias:` unreachable, contradicting the metaslot's own definition. |
| `recommended_check` | The `Recommended` check's fail condition is printed as `<slot>.required=True`. |
| `deprecated_is_a_string` | Deprecation checks compare `deprecated=True`; `deprecated` has range `string`. |

The reference implementation resolves all of these. That is the point: the
difference between "LinkML says" and "the Python implementation does" is real,
and only one of the two is portable.

## Verified against the real metamodel

`meta.yaml` is itself a LinkML schema, so the suite loads it — all 102KB, 40
classes, 216 slots — resolves its six-schema import closure, and derives it. Two
of the interpretations above are checked against published fact rather than
against this gem's own opinion:

- `SafeCamel` and `SafeSnake` must produce the IRIs LinkML actually publishes.
  `class_definition` → `https://w3id.org/linkml/ClassDefinition`; `range` →
  `https://w3id.org/linkml/range`.
- The `alias` handling must let `slot_definitions` surface as `slots`, which a
  literal reading of the pseudocode makes impossible.

Both pass. The fixtures and their hashes are in
[`spec/fixtures/linkml-model/PROVENANCE.md`](spec/fixtures/linkml-model/PROVENANCE.md);
LinkML is CC0.

## Names are unique across definition types

```ruby
Vv::Linkml.load(yaml_with_a_class_and_an_enum_both_named_Status)
# => Vv::Linkml::Schema::NameCollision
```

`02instances.md`: "Names MUST NOT be shared across definition types." The
instance grammar tells `Status(...)`, `Status[...]` and `Status&...` apart by
punctuation alone, so a shared name makes an instance ambiguous. This raises at
load rather than resolving the later definition and moving on.

## Imports

`derive` takes a resolver — a callable from import name to `Schema`. The default
knows `linkml:types` and nothing else. An import it cannot resolve does **not**
raise and does **not** silently vanish:

```ruby
derived.complete?  # => false
derived.gaps
# => ["import \"core\" was not resolved; every class, slot, enum and type it
#     defines is absent from the derived schema"]
```

A name defined in both the importing and the imported schema raises.
`04derived-schemas.md`'s `CombineElements` says so, and LinkML has no import
namespacing to fall back on.

## Layout

| File | What |
|---|---|
| `metamodel.rb` | metaslots and metaclasses, generated from `meta.yaml`; `normative?`, `inheritable?` |
| `types.rb` | the 19 built-in types, generated from `types.yaml`; `miscased` |
| `curie.rb` | `URI`/`CURIE` expansion and contraction; the undefined `Safe*` functions |
| `schema.rb` | an asserted schema, indexed; the cross-type uniqueness rule |
| `definitions.rb` | `ClassDefinition`, `SlotDefinition`, `TypeDefinition`, `EnumDefinition`, `PermissibleValue` |
| `derivation.rb` | part 4: `L`, `K`, `P`, `A`/`A*`, `I`, `ApplicableSlots`, `CombineSlots`, `DerivedSlot`, element URIs |
| `validator.rb` | part 5, for the checks it tabulates; `Report#conclusive?` |
| `unspecified.rb` | the fourteen gaps |

`lib/vv/linkml/metamodel/tables.rb` and `lib/vv/linkml/types/table.rb` are
generated. Do not hand-edit them; regenerate from the fixtures.

## Sources

| | |
|---|---|
| Specification | `linkml/linkml-model`, `linkml_model/model/docs/specification/`, parts 0–7 |
| Metamodel | `meta.yaml` @ `35c91fb01382`, `metamodel_version: 1.11.0` |
| Types | `types.yaml` |
| Read | 2026-09-08 |
| Upstream releases at read time | `linkml-model v1.11.0` (2026-05-14), `linkml v1.11.1` (2026-05-20) |
| License of the sources | CC0 1.0 |

SHA-256 for every file read is in
[`docs/LinkedDataModelingLanguage.md`](docs/LinkedDataModelingLanguage.md).

## License

MIT. See [LICENSE](LICENSE).
