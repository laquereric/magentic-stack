# frozen_string_literal: true

require_relative "linkml/version"
require_relative "linkml/unspecified"
require_relative "linkml/metamodel"
require_relative "linkml/types"
require_relative "linkml/curie"
require_relative "linkml/element"
require_relative "linkml/definitions"
require_relative "linkml/schema"
require_relative "linkml/derivation"
require_relative "linkml/validator"

# The Linked Data Modeling Language as a domain model: its metamodel, the
# derivation procedure that turns an asserted schema into a derived one, the
# validation checks the specification actually tabulates, and — explicitly — the
# line between what the specification states and what an implementation supplies.
#
# Built from the sources named in SPEC, read on 2026-09-08, with the research
# note in docs/LinkedDataModelingLanguage.md recording which file each fact came
# from.
module Vv
  module Linkml
    SPEC = {
      specification: "LinkML Specification, parts 0-7, " \
                     "https://w3id.org/linkml/docs/specification/ " \
                     "(source: linkml/linkml-model, linkml_model/model/docs/specification/)",
      metamodel: "https://w3id.org/linkml/meta.yaml (metamodel_version 1.11.0)",
      types: "https://w3id.org/linkml/types.yaml (19 built-in types)",
      namespace: "https://w3id.org/linkml/",
      authors: ["Chris Mungall, Lawrence Berkeley National Laboratory",
                "Harold Solbrig, Johns Hopkins University"].freeze,
      license: "CC0 1.0 (public domain waiver)",
      read_on: "2026-09-08",

      # 00preamble.md, verbatim. LinkML is not issued by a standards body, and
      # the specification carries no Recommendation-equivalent status. Every
      # answer this gem gives about "what LinkML requires" is an answer about a
      # draft.
      status: "This is a draft specification open from comments to all."
    }.freeze

    # 03schemas.md: the specification covers only the normative subset of the
    # metamodel. Counted from meta.yaml, that is 122 of 216 metaslots and 15 of
    # 40 metaclasses.
    #
    # So "the metamodel has a slot for it" and "the specification says something
    # about it" are different claims, and Metamodel.normative? is the one that
    # answers the second.
    PARTIAL_NORMATIVITY =
      "The LinkML specification specifies only the normative elements necessary " \
      "to specify the behavior of schemas (03schemas.md). meta.yaml marks that " \
      "subset as SpecificationSubset: 122 of 216 metaslots and 15 of 40 " \
      "metaclasses. description, title, comments, examples, see_also and " \
      "deprecated are outside it, and a conforming implementation may ignore " \
      "every one of them."

    class << self
      # Loads a schema from a YAML file.
      def load_file(path, **kwargs) = Schema.load_file(path, **kwargs)

      # Loads a schema from a YAML string.
      def load(yaml, **kwargs) = Schema.load(yaml, **kwargs)

      # Derives a schema: import closure combined, induced slots computed,
      # element URIs resolved. Check `#complete?` on the result before treating
      # anything downstream of it as exhaustive.
      def derive(schema, **kwargs) = Derivation.new(schema).derive(**kwargs)

      # Validates an instance against a target class. Check `#conclusive?` on the
      # report before reading `#valid?` as conformance.
      def validate(instance, schema:, target:, **kwargs)
        Validator.new(schema, **kwargs).validate(instance, target)
      end

      # What the specification, as read, does not say. See Unspecified.
      def gaps = Unspecified.all

      def census = Metamodel.census
    end
  end
end
