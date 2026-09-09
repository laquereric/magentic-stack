# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "vv/linkml"

module Vv; end

module Vv::Graph
  # Runtime slot resolution against an authored LinkML schema.
  #
  # This module used to also derive SHACL in Ruby. It does not any more: LinkML
  # is the source of truth and the upstream Python generators reify it
  # (ADR 0069). Two derivations of one schema is the fragmentation the
  # single-source rule exists to prevent, and the Ruby one was the weaker --
  # upstream emits `sh:closed true` with `sh:ignoredProperties`, which this
  # never did, and closed shapes are what OSI-8 rests on.
  #
  # What remains is the part no generated artifact answers: given a model and a
  # field, what IRI does it carry on the wire and what datatype does it hold.
  # `Vv::Graph::Schema` and `Storable.triples_from_linkml` ask that at runtime.
  #
  #   derived = Vv::Linkml.derive(Vv::Linkml.load_file("config/linkml/note.yaml"))
  #   Vv::Graph::Linkml.field(derived, model: :Note, name: :title)
  #   # => { iri: "urn:mm:vocab/pod#title", xsd: "...#string", ... }
  #
  # The dependency runs one way. vv-linkml models the draft specification and
  # knows nothing about RDF, SHACL or Oxigraph, and must not learn.
  module Linkml
    module_function

    # Resolve one field to its storage-plane surface, from the schema rather
    # than from prefix convention.
    #
    # Returns nil when the schema does not describe the field, so the caller
    # falls through to its existing resolution instead of getting a wrong
    # answer dressed as an authoritative one.
    def field(derived, model:, name:)
      return nil unless derived.respond_to?(:slot_for)

      slot = derived.slot_for(model.to_s, name.to_s)
      return nil if slot.nil?

      {
        iri: slot_iri(derived, slot, model.to_s),
        xsd: xsd_for(derived, slot),
        ar_column: slot.alias_name.to_s,
        multivalued: slot.multivalued?,
        required: slot.effectively_required?,
        source: :linkml
      }
    end

    # The predicate IRI for a slot.
    #
    # vv-linkml resolves URIs for classes, enums and types but deliberately not
    # for slots: the specification's `SafeSnake` decides every slot URI and is
    # never defined, which vv-linkml records as
    # `Unspecified::GAPS[:safe_functions]` rather than papering over. The
    # convention is therefore ours, and there is one defensible pick -- the one
    # already on the wire. `Vv::Graph::Schema` emits `<prefix><Model>/<field>`,
    # and a shape using any other shape would target predicates no triple in
    # the store carries.
    #
    # An asserted `slot_uri` wins; that is the schema author overriding the
    # convention on purpose.
    def slot_iri(derived, slot, class_name = nil)
      asserted = expand(derived, slot.slot_uri)
      return asserted if asserted

      resolved = derived.uri_for(slot.name)
      return resolved.to_s if resolved

      return nil if class_name.nil?

      "#{derived.schema.default_namespace}#{class_name}/#{slot.alias_name}"
    end

    # An asserted `slot_uri` is a CURIE when its prefix is one the schema
    # declares, and an absolute IRI otherwise. The two are not distinguishable
    # by shape -- `pod:title` and `urn:mm:vocab/pod#title` both read as
    # `scheme:rest` -- so the prefix map decides, and only the prefix map.
    #
    # Testing for a leading "http" instead, which is the obvious shortcut,
    # silently discards every URN a schema asserts and falls through to the
    # derived convention. The triples then land under a predicate nothing
    # queries.
    def expand(derived, curie_or_iri)
      return nil if curie_or_iri.nil? || curie_or_iri.empty?

      prefix, _, rest = curie_or_iri.partition(":")
      return curie_or_iri if rest.empty?

      expansion = derived.schema.expanded_prefixes[prefix]
      expansion ? "#{expansion}#{rest}" : curie_or_iri
    rescue StandardError
      curie_or_iri
    end

    def xsd_for(derived, slot)
      range = slot.range
      return nil if range.nil?

      builtin = ::Vv::Linkml::Types[range]
      return builtin.uri if builtin

      declared = derived.schema.type(range)
      declared&.uri
    end
  end
end
