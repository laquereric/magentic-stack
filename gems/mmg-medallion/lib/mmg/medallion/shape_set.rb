# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"
require_relative "n_triples"

module Mmg
  module Medallion
    # Named SHACL-shape sets: mmg_shacl_v1 (M2).
    #
    # A flow's shape_set names one of these. Validation is structural
    # plus declared constraints -- every line must parse as N-Triples,
    # blank nodes and non-IRI subjects fail unless the set allows them,
    # predicates outside the allow-list fail when the set names one, and
    # required predicates must occur. The report persists on the conform
    # result (and links onto the promotion); SHACL remains a GATE, never
    # a transform.
    #
    # Deliberately not full W3C SPARQL-SHACL: no property paths, no
    # qualified shapes, no SPARQL-based constraints. A blank-line check is
    # no longer the gate; a blank-node check is.
    class ShapeSet
      REGISTRY = {}

      ENGINE = "mmg_shacl_v1"

      attr_reader :name, :allow_predicates, :required_predicates,
                  :require_subjects_iri, :allow_blank_nodes

      def initialize(name, allow_predicates: nil, required_predicates: [],
                     require_subjects_iri: true, allow_blank_nodes: false)
        @name = name.to_s
        @allow_predicates = allow_predicates&.map(&:to_s)
        @required_predicates = Array(required_predicates).map(&:to_s)
        @require_subjects_iri = !!require_subjects_iri
        @allow_blank_nodes = !!allow_blank_nodes
      end

      def self.register(name, **kwargs)
        set = new(name, **kwargs)
        REGISTRY[set.name] = set
        set
      end

      def self.for(name) = REGISTRY[name.to_s]

      def self.clear!
        REGISTRY.clear
        { ok: true }
      end

      def validate(triple_strings)
        violations = []
        seen_predicates = []
        lines = Array(triple_strings).map(&:to_s)

        if lines.empty?
          violations << "bronze triple set empty"
        end

        lines.each_with_index do |line, i|
          parsed = NTriples.parse(line)
          unless parsed[:ok]
            violations << "line #{i}: #{parsed[:because]}"
            next
          end

          terms = [parsed[:s], parsed[:p], parsed[:o]]
          if terms.any? { |t| t[:kind] == :blank } && !allow_blank_nodes
            violations << "line #{i}: blank node (bnode subjects/objects are not addressable Silver identity)"
          end
          if require_subjects_iri && parsed[:s][:kind] != :iri
            violations << "line #{i}: subject is not an IRI"
          end
          if parsed[:p][:kind] != :iri
            violations << "line #{i}: predicate is not an IRI"
          elsif !allow_predicates.nil? && !allow_predicates.include?(parsed[:p][:value])
            violations << "line #{i}: predicate <#{parsed[:p][:value]}> not in shape #{name}"
          end
          seen_predicates << parsed[:p][:value] if parsed[:p][:kind] == :iri
        end

        required_predicates.each do |required|
          unless seen_predicates.include?(required)
            violations << "required predicate <#{required}> absent from shape #{name}"
          end
        end

        {
          ok: violations.empty?, shape_set: name, n: lines.size,
          violations: violations, engine: ENGINE
        }
      end
    end
  end
end
