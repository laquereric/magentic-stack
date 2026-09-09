# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "vv/linkml"

module Vv; end

module Vv::Graph
  # LinkML is the authoring language; RDF/SHACL is still what goes on the wire.
  #
  # This adapter reads a `Vv::Linkml` schema, runs the specification's part-4
  # derivation, and emits SHACL Core shapes as Turtle for the existing
  # `Vv::Graph::Shacl::Loader` to put in the `:shapes` scope. Nothing here
  # validates: `Vv::Graph::Shacl.validate` still does that, against triples in
  # Oxigraph, exactly as before. The change is where the shapes come from, not
  # what the store or the validator sees.
  #
  #   schema  = Vv::Linkml.load_file("config/linkml/note.yaml")
  #   Vv::Graph::Linkml.load_shapes(schema)
  #   # => { ok: true, loaded: 24, scope: "urn:vv-graph:shapes",
  #   #      node_shapes: 2, conclusive: true }
  #
  # The dependency runs one way — vv-graph requires vv-linkml, never the
  # reverse. vv-linkml stays a zero-dependency model of the draft
  # specification and knows nothing about RDF, SHACL or Oxigraph.
  #
  # ## Why an incomplete derivation refuses instead of emitting
  #
  # `Vv::Linkml::DerivedSchema#complete?` is false when the import closure did
  # not resolve, when an enum draws its values from an external ontology, or
  # when a range names nothing. Shapes derived over that schema are not wrong
  # so much as *short*: they carry no constraint for what the derivation never
  # saw, and `Vv::Graph::Shacl.validate` would then report `conforms: true`
  # over data nobody actually checked. That is the same trap vv-linkml's
  # `conclusive?` exists to name, and a silent pass is worse here than in a
  # report, because these shapes persist in the store.
  #
  # So `strict: true` (the default) refuses with `:linkml_derivation_incomplete`
  # and hands back `gaps`. `strict: false` emits anyway and marks the envelope
  # `conclusive: false` — for the case where partial shapes are wanted
  # deliberately and the caller has read what is missing.
  #
  # ## What maps, and what does not
  #
  # Slots become `sh:PropertyShape`s: cardinality from `required` /
  # `identifier` / `key` / `multivalued` (explicit `minimum_cardinality` and
  # `maximum_cardinality` win where asserted), `pattern` to `sh:pattern`,
  # `minimum_value` / `maximum_value` to `sh:minInclusive` / `sh:maxInclusive`,
  # and the range to `sh:datatype`, `sh:class` or `sh:in` by metatype.
  #
  # LinkML's boolean slot expressions (`any_of`, `all_of`, `none_of`,
  # `exactly_one_of`) have SHACL counterparts, but the mapping is only sound
  # for the sub-cases where each branch is itself expressible; rather than
  # guess, a slot carrying one is reported in `unmapped` and its other
  # constraints still emit. `unique_keys` and class `rules` are likewise
  # reported rather than invented — the LinkML validation chapter leaves four
  # of those sections as headings with no bodies, so there is no specified
  # behaviour to transcribe.
  module Linkml
    DEFAULT_SHAPES_SCOPE = "urn:vv-graph:shapes"
    SHAPE_NS             = "urn:vv-graph:shape:"

    SH  = "http://www.w3.org/ns/shacl#"
    XSD = "http://www.w3.org/2001/XMLSchema#"

    module_function

    # Derive shapes and hand them to the existing SHACL loader.
    #
    # The loader owns idempotency: it hashes the Turtle and returns
    # `loaded: 0, reason: :unchanged` when the shapes have not moved.
    def load_shapes(schema, scope: nil, strict: true)
      derived = shapes(schema, scope: scope, strict: strict)
      return derived unless derived[:ok]

      env = ::Vv::Graph::Shacl::Loader.load(
        derived[:ttl], format: :ttl, scope: scope || DEFAULT_SHAPES_SCOPE
      )
      return env unless env.is_a?(Hash) && env[:ok]

      env.merge(
        node_shapes: derived[:node_shapes],
        property_shapes: derived[:property_shapes],
        conclusive: derived[:conclusive],
        gaps: derived[:gaps],
        unmapped: derived[:unmapped]
      )
    end

    # Derive SHACL Turtle from a LinkML schema. Never raises.
    def shapes(schema, scope: nil, strict: true)
      derived = derive(schema)
      return derived if derived.is_a?(Hash)

      unless derived.complete?
        return refuse(:linkml_derivation_incomplete, gaps: derived.gaps) if strict
      end

      unmapped = []
      blocks   = derived.class_names.filter_map do |class_name|
        node_shape(derived, class_name, unmapped)
      end

      {
        ok: true,
        ttl: [header, *blocks].join("\n"),
        node_shapes: blocks.length,
        property_shapes: property_count(derived),
        scope: scope || DEFAULT_SHAPES_SCOPE,
        conclusive: derived.complete?,
        gaps: derived.gaps,
        unmapped: unmapped
      }
    end

    # Resolve one field to its storage-plane surface, from LinkML rather than
    # from prefix convention. Feeds `Vv::Graph::Schema.field`.
    #
    # Returns nil when the schema does not describe the field, so the caller
    # can fall through to its existing resolution rather than get a wrong
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

    # --- derivation -------------------------------------------------------

    def derive(schema)
      schema = ::Vv::Linkml.load_file(schema.to_s) if schema.is_a?(String) || schema.is_a?(Pathname)
      return ::Vv::Linkml.derive(schema) unless schema.respond_to?(:complete?)

      schema
    rescue Errno::ENOENT => e
      refuse(:linkml_schema_not_found, detail: e.message)
    rescue StandardError => e
      refuse(:linkml_schema_unreadable, detail: "#{e.class}: #{e.message}")
    end

    def property_count(derived)
      derived.class_names.sum { |c| derived.slots_for(c).length }
    end

    # --- shape emission ---------------------------------------------------

    def node_shape(derived, class_name, unmapped)
      slots = derived.slots_for(class_name)
      return nil if slots.empty?

      target = derived.uri_for(class_name)
      shape  = "<#{SHAPE_NS}#{class_name}>"

      lines = ["#{shape} a sh:NodeShape ;"]
      lines << "  sh:targetClass <#{target}> ;" if target

      props = slots.filter_map { |slot_name, slot| property_shape(derived, class_name, slot_name, slot, unmapped) }
      lines << props.join(" ;\n")
      lines << "  .\n"
      lines.join("\n")
    end

    def property_shape(derived, class_name, slot_name, slot, unmapped)
      path = slot_iri(derived, slot, class_name)
      return nil if path.nil?

      if slot.boolean_expressions?
        unmapped << { class: class_name, slot: slot_name, reason: :boolean_slot_expression }
      end

      parts = ["    sh:path <#{path}>"]

      min = slot.minimum_cardinality || (slot.effectively_required? ? 1 : nil)
      max = slot.maximum_cardinality || (slot.multivalued? ? nil : 1)
      parts << "    sh:minCount #{min}" if min
      parts << "    sh:maxCount #{max}" if max

      range = range_constraint(derived, slot)
      parts << range if range

      parts << "    sh:pattern #{quote(slot.pattern)}" if slot.pattern
      parts << "    sh:minInclusive #{literal(slot.minimum_value)}" unless slot.minimum_value.nil?
      parts << "    sh:maxInclusive #{literal(slot.maximum_value)}" unless slot.maximum_value.nil?

      "  sh:property [\n#{parts.join(" ;\n")}\n  ]"
    end

    def range_constraint(derived, slot)
      range = slot.range
      return nil if range.nil?

      case derived.schema.range_metatype(range)
      when :builtin_type, :type
        uri = xsd_for(derived, slot)
        uri ? "    sh:datatype <#{uri}>" : nil
      when :class
        target = derived.uri_for(range)
        target ? "    sh:class <#{target}>" : nil
      when :enum
        values = derived.schema.enum(range)&.texts
        return nil if values.nil? || values.empty?

        "    sh:in (#{values.map { |v| quote(v) }.join(' ')})"
      end
    end

    # --- term helpers -----------------------------------------------------

    # The predicate IRI for a slot.
    #
    # vv-linkml resolves URIs for classes, enums and types but deliberately not
    # for slots: the specification's `SafeSnake` is used to derive every slot
    # URI and never defined, which vv-linkml records as
    # `Unspecified::GAPS[:safe_functions]` rather than papering over. The
    # convention is therefore ours to pick, and there is only one defensible
    # pick — the one already on the wire. `Vv::Graph::Schema` emits
    # `<prefix><Model>/<field>`, and shapes that used any other shape would
    # target predicates no triple in the store carries.
    #
    # An asserted `slot_uri` still wins; that is the schema author overriding
    # the convention on purpose.
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
    # by shape — `pod:title` and `urn:mm:vocab/pod#title` both look like
    # `scheme:rest` — so the prefix map decides, and only the prefix map.
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

    def header
      <<~TTL
        @prefix sh:  <#{SH}> .
        @prefix xsd: <#{XSD}> .
      TTL
    end

    def quote(value)
      %("#{value.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}")
    end

    def literal(value)
      case value
      when Numeric then value.to_s
      else quote(value)
      end
    end

    def refuse(symbol, **detail)
      { ok: false, refusal: symbol, conclusive: false }.merge(detail)
    end
  end
end
