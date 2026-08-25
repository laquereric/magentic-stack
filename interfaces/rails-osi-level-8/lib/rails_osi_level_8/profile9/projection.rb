# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # AN ACIA DOCUMENT, AS TRIPLES.
    #
    # ACIA.md asks for a SPARQL surface over the presentation tree, and there was
    # nothing behind it: Profile 9 renders to HTML and stops. This is the missing
    # projection -- document in, N-Triples out -- and it is the whole of what
    # this file does.
    #
    # PURE. No ActiveRecord, no HTTP, no store. mmg-acia owns Node and Triple
    # rows and mmg-graph owns the publish path; teaching this gem about either
    # would couple a profile to a storage layer it does not need in order to
    # describe itself. What comes back is strings, and the caller decides where
    # they land.
    #
    # WHY A SEPARATE GRAPH AND SEPARATE PREDICATES.
    #
    # There are two ACIAs in this codebase (see ADR 0003). Mmg::Acia::Node has a
    # semantic_role too, and it means something else -- SAL's is free text with
    # an ARIA mapping, Profile 9's is one of a closed fourteen. Folding one onto
    # the other would be the drift the closed vocabulary exists to prevent. So
    # the SLT tuple gets FIVE predicates of its own and the triples land in their
    # own named graph. Nothing is bent to fit, and the graph records which model
    # each statement came from.
    module Projection
      module_function

      VOCAB = "urn:mm:vocab/acia#"
      # A prop is a key and a value. Rather than reify, each key becomes a
      # predicate under its own namespace -- so the prop TABLE survives as a
      # table, and `?node acia-prop:title ?t` is a query a person can write.
      PROP_VOCAB = "urn:mm:vocab/acia/prop#"
      RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

      # The default graph for Profile 9 presentation. NOT urn:mmg:sal:public --
      # that is where mmg-sal pane trees live, and mixing the two would put two
      # vocabularies in one namespace with no way to tell them apart afterwards.
      DEFAULT_GRAPH = "urn:mm:graph:acia:profile9"

      SLT_PREDICATES = {
        "semanticRole" => "semanticRole",
        "contentRole" => "contentRole",
        "layoutKind" => "layoutKind",
        "layoutArity" => "layoutArity",
        "behaviorKind" => "behaviorKind"
      }.freeze

      # THE SAME IDENTITY THE RENDERER MINTS, derived the same way.
      #
      # renderer.rb:111 computes cid:node:<sha256(digest:nodeId)[0,16]> and puts
      # it on the element as data-ux-node-cid. The first cut of this file hashed
      # the node itself instead, which produced valid triples naming things no
      # rendered element carried -- a graph that looks joinable to the DOM and
      # is not. There is one derivation and both callers use it.
      def node_iri(node_id, digest)
        "urn:mm:acia:node:#{Digest::SHA256.hexdigest("#{digest}:#{node_id}")[0, 16]}"
      end

      def document_iri(digest) = "urn:mm:acia:document:#{digest.to_s.sub(/\Asha256:/, '')}"

      # Never raises: a document that cannot be walked yields an envelope, not a
      # stack trace, because this runs behind a CPCP boundary.
      # `slug` names WHICH surface this document is. Without it the store holds a
      # digest and no way to ask "what is the board now" -- every published
      # snapshot looks alike and only the digest tells them apart, which is the
      # one thing a reader does not have in hand.
      def triples(acia, graph: DEFAULT_GRAPH, slug: nil)
        doc = acia.is_a?(Hash) ? acia : {}
        root = doc["root"] || doc["rootNode"]
        return refuse(:no_root, "an ACIA document with no root projects nothing") unless root.is_a?(Hash)

        digest = Acia.validate(doc).digest.to_s
        doc_iri = document_iri(digest)
        out = [
          triple(doc_iri, RDF_TYPE, iri: "#{VOCAB}Document"),
          triple(doc_iri, "#{VOCAB}aciaDigest", literal: digest),
          triple(doc_iri, "#{VOCAB}schemaVersion", literal: doc["schemaVersion"].to_s),
          triple(doc_iri, "#{VOCAB}componentRegistryVersion", literal: doc["componentRegistryVersion"].to_s)
        ]
        out << triple(doc_iri, "#{VOCAB}slug", literal: slug.to_s) unless slug.to_s.empty?

        count = 0
        walk(root, nil, 0) do |node, parent, position|
          count += 1
          out.concat(node_triples(node, parent, position, doc_iri, digest))
        end

        { ok: true, graph: graph, digest: digest, document: doc_iri,
          nodes: count, triples: out.compact }
      rescue StandardError => e
        refuse(:projection_failed, "#{e.class}: #{e.message}")
      end

      def node_triples(node, parent, position, doc_iri, digest)
        s = node_iri(node["nodeId"], digest)
        v = node.dig("props", "valueJson") || {}
        slt = node["slt"] || {}

        out = [
          triple(s, RDF_TYPE, iri: "#{VOCAB}Node"),
          triple(s, "#{VOCAB}inDocument", iri: doc_iri),
          triple(s, "#{VOCAB}nodeId", literal: node["nodeId"].to_s),
          triple(s, "#{VOCAB}componentKind", literal: node["componentKind"].to_s),
          triple(s, "#{VOCAB}position", literal: position.to_s)
        ]
        out << triple(s, "#{VOCAB}parent", iri: node_iri(parent["nodeId"], digest)) if parent

        SLT_PREDICATES.each do |key, pred|
          value = slt[key].to_s
          out << triple(s, "#{VOCAB}#{pred}", literal: value) unless value.empty?
        end

        # The prop table. Scalars only: a nested prop is structure, and structure
        # is what the tree already expresses.
        v.each do |key, value|
          next if value.is_a?(Hash) || value.is_a?(Array)
          next if value.nil? || value.to_s.empty?

          out << triple(s, "#{PROP_VOCAB}#{key}", literal: value.to_s)
        end

        out
      end
      private_class_method :node_triples

      def walk(node, parent, position, &block)
        return unless node.is_a?(Hash)

        block.call(node, parent, position)
        Array(node["children"]).each_with_index { |c, i| walk(c, node, i, &block) }
      end
      private_class_method :walk

      def triple(subject, predicate, iri: nil, literal: nil)
        object = iri ? "<#{iri}>" : %("#{escape(literal)}")
        "<#{subject}> <#{predicate}> #{object} ."
      end
      private_class_method :triple

      # N-Triples escaping. A board carries prose with quotes and newlines in it,
      # and an unescaped one produces a file the store rejects wholesale -- so the
      # failure is never the one triple that was wrong.
      def escape(value)
        value.to_s
             .gsub("\\", "\\\\\\\\")
             .gsub('"', '\\"')
             .gsub("\n", "\\n")
             .gsub("\r", "\\r")
             .gsub("\t", "\\t")
      end
      private_class_method :escape

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
