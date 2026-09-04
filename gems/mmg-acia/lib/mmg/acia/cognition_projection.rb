# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    # THE COGNITION HALF.
    #
    # A tree of nodes produces two artifacts: something a person sees and
    # something a model reads. Profile 9 governs the first. This is the second,
    # against Profile 2 (reference-passing for agents), whose thesis is that a
    # model reads context BY REFERENCE -- a bounded preview plus a portable
    # handle it can dereference when it needs the whole thing.
    #
    # That is what entity_iri has always been: the handle. This projection makes
    # it say so in the vocabulary the profile defines.
    #
    # Pure -- no AR, no HTTP, no store. It takes rows and returns N-Triples, so
    # the same code runs over a live tree and over a fixture.
    module CognitionProjection
      module_function

      P2 = "https://w3id.org/cpcp/ps1-p2/ns#"
      CPCP = "https://w3id.org/cpcp/ns#"
      RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

      # Its own named graph. The presentation projection and this one describe the
      # same tree in different vocabularies for different readers; mixing them
      # leaves no way to ask for one without the other.
      DEFAULT_GRAPH = "urn:mm:graph:acia:cognition"

      # p2:PreviewShape is sh:closed over exactly previewText + references, and
      # references is minCount 1 -- so a preview with no referent is not a preview.
      # A node with no entity_iri produces NONE, rather than one pointing nowhere.
      def preview_triples(node)
        ref = value_of(node, :entity_iri).to_s
        return [] unless iri?(ref)

        s = preview_iri(node)
        out = [triple(s, RDF_TYPE, iri: "#{P2}Preview"),
               triple(s, "#{CPCP}references", iri: ref)]

        text = preview_text_for(node)
        out << triple(s, "#{P2}previewText", literal: text) unless text.empty?
        out
      end

      # cpcp:InsightShape: a summary ABOUT something, referencing any number of
      # handles. A subtree's insight references every entity the subtree names --
      # which is the set a model would have to dereference to act on it.
      def insight_triples(root, descendants: [])
        summary = value_of(root, :cognition_summary).to_s.strip
        return [] if summary.empty?

        s = insight_iri(root)
        out = [triple(s, RDF_TYPE, iri: "#{CPCP}Insight"),
               triple(s, "#{P2}summary", literal: summary)]

        ([root] + Array(descendants)).each do |n|
          ref = value_of(n, :entity_iri).to_s
          out << triple(s, "#{CPCP}references", iri: ref) if iri?(ref)
        end
        out.uniq
      end

      # The whole tree as one artifact: a preview per referring node, plus the
      # root's insight over all of them.
      def tree_triples(root, descendants: [])
        nodes = [root] + Array(descendants)
        out = nodes.flat_map { |n| preview_triples(n) }
        out + insight_triples(root, descendants: descendants)
      end

      # Named from the node, so a preview is findable from the thing that made it
      # even though the shape -- being closed -- cannot carry a link back.
      def preview_iri(node) = "#{node_iri(node)}/preview"
      def insight_iri(node) = "#{node_iri(node)}/insight"

      # WHAT THE MODEL READS, which is not always what the pane shows. Falls back
      # to the visible text when a node has nothing further to say -- better a
      # true short preview than none.
      def preview_text_for(node)
        explicit = value_of(node, :preview_text).to_s.strip
        return explicit unless explicit.empty?

        value_of(node, :value).to_s.strip
      end

      def node_iri(node)
        return node.iri if node.respond_to?(:iri)

        "urn:mmg:sal:acia:#{value_of(node, :id)}"
      end

      def value_of(node, key)
        if node.respond_to?(key) then node.public_send(key)
        elsif node.respond_to?(:[]) then node[key] || node[key.to_s]
        end
      end

      # cpcp:references is sh:nodeKind sh:IRI. A bare token is not an IRI, and
      # emitting one produces a triple that parses and means nothing.
      def iri?(value) = value.to_s.match?(%r{\A[a-z][a-z0-9+.-]*:[^\s]+\z}i)

      def triple(subject, predicate, iri: nil, literal: nil)
        object = iri ? "<#{iri}>" : %("#{escape(literal)}")
        "<#{subject}> <#{predicate}> #{object} ."
      end

      def escape(value)
        value.to_s.gsub("\\", "\\\\\\\\").gsub('"', '\\"')
             .gsub("\n", "\\n").gsub("\r", "\\r").gsub("\t", "\\t")
      end
    end
  end
end
