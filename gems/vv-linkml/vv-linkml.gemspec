# frozen_string_literal: true

require_relative "lib/vv/linkml/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-linkml"
  spec.version = Vv::Linkml::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary     = "LinkML as a domain model: the metamodel, the derivation " \
                     "procedure, and the line between what the draft specifies " \
                     "and what an implementation supplies."
  spec.description = <<~DESC.strip
    vv-linkml models the Linked Data Modeling Language from its own sources --
    meta.yaml, types.yaml, and the seven specification chapters -- rather than
    from prose about them. That distinction earns its keep immediately: the
    specification's own list of built-in types names 14 of the 19 that exist, and
    prints them capitalised, though a schema written `range: Boolean` resolves to
    nothing and silently falls through to default_range.

    Two facts organise the gem. First, LinkML is a DRAFT: "This is a draft
    specification open from comments to all." Second, most of the metamodel
    carries no normative weight -- 122 of 216 metaslots and 15 of 40 metaclasses
    are in the SpecificationSubset, so `description`, `comments` and `deprecated`
    are things a conforming implementation may ignore. Metamodel.normative?
    answers that per metaslot, and the gem never conflates "the metamodel has it"
    with "the specification requires it".

    The derivation procedure of part 4 is implemented with its function names
    intact, and every induced slot carries provenance: which of slot_usage, an
    attribute, the top-level slot, a slot ancestor or a default supplied each
    metaslot value. Where part 4 is underdetermined -- PK() is used and never
    defined, SafeCamel and SafeSnake decide every derived URI and are never
    defined, AddMissingValues keys on a metaslot that is not in meta.yaml --
    the gem picks an interpretation, names it in Unspecified::GAPS, and points
    the affected code back at it.

    Validation reports carry `conclusive?` alongside `valid?`. Four sections of
    the validation chapter are headings with no bodies, covering class rules,
    unique_keys, classification rules and value inference; a schema that leans on
    them gets a report that says so rather than a quiet pass over a subset.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.metadata["source_code_uri"] = "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-linkml"

  spec.files = Dir["lib/**/*.rb", "README.md", "VERSION", "LICENSE", "*.gemspec",
                   "docs/**/*.md"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
end
