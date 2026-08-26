# frozen_string_literal: true

require_relative "vocabulary"

module Mmg
  module Adr
    # Attributes -> N-Triples. Pure, like Profile 9's projection: no AR, no HTTP,
    # no store. What grounds these triples is decided by the caller, which passes
    # a persisted Mmg::Graph::Entry to Mmg::Graph::Execute.publish.
    module Projection
      module_function

      def triples(attrs)
        attrs = stringify(attrs)
        id = attrs["adr_id"]
        return [] if id.nil? || id.to_s.empty?

        s = iri(Vocabulary.subject_iri(id))
        out = ["#{s} #{iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')} #{iri(Vocabulary::CLASS_IRI)} ."]

        Vocabulary::SCALARS.each do |key, predicate|
          value = attrs[key]
          next if value.nil? || value.to_s.empty?

          out << "#{s} #{iri(predicate)} #{literal(value)} ."
        end

        Vocabulary::LISTS.each do |key, predicate|
          Array(attrs[key]).each do |value|
            next if value.nil? || value.to_s.empty?

            out << "#{s} #{iri(predicate)} #{literal(value)} ."
          end
        end

        # An ADR-to-ADR edge points at a subject IRI, not a string, so the ledger
        # is walkable: a superseded record leads to the one(s) that replaced it.
        # One triple per successor -- a split leaves both edges in the graph.
        Vocabulary::LINKS.each do |key, predicate|
          Array(attrs[key]).each do |value|
            next if value.nil? || value.to_s.empty?

            out << "#{s} #{iri(predicate)} #{iri(Vocabulary.subject_iri(value))} ."
          end
        end

        out
      end

      def iri(value) = "<#{value}>"

      def literal(value)
        escaped = value.to_s
                       .gsub("\\", "\\\\\\\\")
                       .gsub('"', '\\"')
                       .gsub("\n", "\\n")
                       .gsub("\r", "\\r")
                       .gsub("\t", "\\t")
        "\"#{escaped}\""
      end

      def stringify(attrs)
        return {} unless attrs.respond_to?(:each_pair)

        attrs.each_pair.to_h { |k, v| [k.to_s, v] }
      end
    end
  end
end
