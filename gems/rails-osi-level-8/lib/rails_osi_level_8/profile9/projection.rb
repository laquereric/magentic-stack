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

      # THE SPECIFICATION'S OWN VOCABULARY.
      #
      # Profile 9 specifies these types in its normative shapes; this projection
      # implements them, so it uses the specified names rather than a parallel set
      # that agrees only in spelling.
      VOCAB = "https://w3id.org/cpcp/osi8/ux#"
      # A prop is a key and a value. Rather than reify, each key becomes a
      # predicate under its own namespace -- so the prop TABLE survives as a
      # table, and `?node acia-prop:title ?t` is a query a person can write.
      PROP_VOCAB = "urn:mm:vocab/acia/prop#"
      RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
      RDF_NS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      XSD = "http://www.w3.org/2001/XMLSchema#"
      # The values GovernedFieldsShape actually constrains: profileId is
      # sh:hasValue on the full id, cid matches ^cid:, digest matches ^sha256:,
      # and created/wasGeneratedBy are dct:/prov: -- NOT ux:. Guessing the
      # namespace produces triples the shape never sees.
      PROFILE_ID = "osi-level-8/profile-9"
      DCT_CREATED = "http://purl.org/dc/terms/created"
      PROV_GENERATED_BY = "http://www.w3.org/ns/prov#wasGeneratedBy"
      GENERATOR_IRI = "https://w3id.org/cpcp/osi8/ux#profile-9-projection"
      # Used when the caller supplies none. A fixed value keeps the projection
      # deterministic; a caller that cares about real provenance passes its own.
      DEFAULT_CREATED = "1970-01-01T00:00:00Z"

      # The classes the shapes actually target. ux:ComponentShape targets
      # view:Widget, not a class of ours -- a node typed anything else is simply
      # not the thing the shape describes, and validation passes by never looking.
      VIEW_VOCAB = "https://w3id.org/cpcp/view#"
      WIDGET_CLASS = "#{VIEW_VOCAB}Widget"
      DOCUMENT_CLASS = "#{VOCAB}AciaDocument"

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

      # A dimension value is a term in the specified vocabulary: ux:heading, not
      # "heading" and not a namespace of our own.
      def term_iri(token) = "#{VOCAB}#{token}"

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
      # `created` is an INPUT, not a clock read.
      #
      # GovernedFieldsShape requires dct:created, and taking it from Time.now made
      # the projection non-deterministic: the same document produced different
      # triples on every call, which breaks the guarantee that a projection is a
      # pure function of its document. The caller knows when the record was made;
      # this does not.
      def triples(acia, graph: DEFAULT_GRAPH, slug: nil, created: nil)
        doc = acia.is_a?(Hash) ? acia : {}
        root = doc["root"] || doc["rootNode"]
        return refuse(:no_root, "an ACIA document with no root projects nothing") unless root.is_a?(Hash)

        # REFUSE A DOCUMENT THAT DOES NOT VALIDATE.
        #
        # This read .digest off the result and ignored .conforms?, so a document
        # that failed the gate was still projected -- with an EMPTY digest, which
        # then failed the ^sha256: pattern GovernedFieldsShape requires. Projecting
        # something the profile has already refused produces triples that claim
        # governance they do not have.
        validation = Acia.validate(doc)
        unless validation.conforms?
          return refuse(:acia_invalid,
                        "the document does not conform to Profile 9, so it has no digest to project: " \
                        "#{validation.reason}")
        end

        digest = validation.digest.to_s
        created = created.nil? ? DEFAULT_CREATED : created.to_s
        doc_iri = document_iri(digest)
        out = [
          triple(doc_iri, RDF_TYPE, iri: DOCUMENT_CLASS),
          triple(doc_iri, "#{VOCAB}schemaVersion", literal: doc["schemaVersion"].to_s),
          triple(doc_iri, "#{VOCAB}componentRegistryVersion", literal: doc["componentRegistryVersion"].to_s),
          triple(doc_iri, "#{VOCAB}renderContractDigest", literal: digest.to_s),
          triple(doc_iri, "#{VOCAB}ledgerPlacement", iri: term_iri("canonical")),
          triple(doc_iri, "#{VOCAB}rootNode", iri: node_iri(root["nodeId"], digest)),
          # AciaDocumentShape requires the root to be a view:Container. Nothing in
          # the spec types anything as one, so the root carries both: it IS the
          # container of the tree as well as a widget in it.
          triple(node_iri(root["nodeId"], digest), RDF_TYPE, iri: "#{VIEW_VOCAB}Container")
        ]
        out.concat(governed_triples(doc_iri, digest, created))

        count = 0
        walk(root, nil, 0) do |node, parent, position|
          count += 1
          out.concat(node_triples(node, parent, position, doc_iri, digest, created))
        end

        { ok: true, graph: graph, digest: digest, document: doc_iri,
          nodes: count, triples: out.compact }
      rescue StandardError => e
        refuse(:projection_failed, "#{e.class}: #{e.message}")
      end

      def node_triples(node, parent, position, doc_iri, digest, created)
        s = node_iri(node["nodeId"], digest)
        slt = node["slt"] || {}

        # ux:ComponentShape is sh:closed over exactly these, plus the ungoverned
        # GovernedFields. Anything else on a view:Widget is a violation, so the
        # projection emits what the shape admits and nothing beside it.
        out = [
          triple(s, RDF_TYPE, iri: WIDGET_CLASS),
          triple(s, "#{VOCAB}nodeId", literal: node["nodeId"].to_s),
          triple(s, "#{VOCAB}componentKind", iri: term_iri(node["componentKind"].to_s))
        ]
        out.concat(governed_triples(s, digest, created))
        out.concat(slt_triples(s, slt))
        out.concat(props_triples(s, node["props"]))
        out.concat(variant_triples(s, node["variant"]))

        # CONTAINMENT RUNS PARENT -> CHILD, which is the direction the shape
        # models (`ux:child sh:class ux:Widget`). It used to run child -> parent
        # under a ux:parent predicate that the closed shape has no slot for.
        Array(node["children"]).each do |c|
          next unless c.is_a?(Hash)

          out << triple(s, "#{VOCAB}child", iri: node_iri(c["nodeId"], digest))
        end

        out
      end
      private_class_method :node_triples

      # ux:GovernedFieldsShape -- required of every governed node, and NOT closed,
      # so these are additive rather than exhaustive. cid and digest are derived
      # from the node's own identity: a governed record that cannot say what it is
      # is not governed.
      def governed_triples(subject, digest, created)
        [
          triple(subject, "#{VOCAB}cid", literal: "cid:#{subject.split(':').last}"),
          triple(subject, "#{VOCAB}digest", literal: digest.to_s),
          triple(subject, "#{VOCAB}profileId", literal: PROFILE_ID),
          triple(subject, "#{VOCAB}ledgerPlacement", iri: term_iri("canonical")),
          triple(subject, DCT_CREATED, literal: created, datatype: "#{XSD}dateTime"),
          triple(subject, PROV_GENERATED_BY, iri: GENERATOR_IRI)
        ]
      end
      private_class_method :governed_triples

      # ux:TypedPropsShape is closed over propsSchemaCid + valueJson. The prop
      # TABLE is gone: it put one predicate per key straight onto the component,
      # which the closed ComponentShape refuses. The values live in valueJson,
      # which is what the shape says they are.
      def props_triples(subject, props)
        return [] unless props.is_a?(Hash)

        n = "#{subject}/props"
        [
          triple(subject, "#{VOCAB}props", iri: n),
          triple(n, RDF_TYPE, iri: "#{VOCAB}TypedProps"),
          triple(n, "#{VOCAB}propsSchemaCid", iri: props["propsSchemaCid"].to_s),
          triple(n, "#{VOCAB}valueJson", literal: JSON.generate(props["valueJson"] || {}), datatype: "#{RDF_NS}JSON")
        ]
      end
      private_class_method :props_triples

      def variant_triples(subject, variant)
        # The document carries variant either as a bare name or as the
        # VariantSelection object the shape describes. Stringifying the object
        # produced a term IRI with a whole Ruby hash inside it -- malformed RDF
        # that no parser would read.
        name = variant.is_a?(Hash) ? (variant["variantName"] || variant[:variantName]).to_s : variant.to_s
        name = "default" if name.empty?
        n = "#{subject}/variant"
        [
          triple(subject, "#{VOCAB}variant", iri: n),
          triple(n, RDF_TYPE, iri: "#{VOCAB}VariantSelection"),
          triple(n, "#{VOCAB}variantName", iri: term_iri(name))
        ]
      end
      private_class_method :variant_triples


      # THE TUPLE IS A NODE, because ux:ComponentShape says
      # `ux:slt sh:class ux:SLTTuple` -- the five dimensions belong to the tuple,
      # not to the component. Flattening them onto the node loses the tuple as a
      # thing that can be pointed at, compared, or reused.
      #
      # ux:SLTTupleShape is sh:closed with exactly seven properties, all required,
      # so this emits all seven or the tuple does not conform. tokenSignature is
      # sh:class ux:TokenSignature -- another node -- and the spec defines no
      # shape for it, so its scalars are carried through without inventing
      # structure the specification has not stated.
      def slt_triples(node_subject, slt)
        return [] if slt.nil? || slt.empty?

        t = tuple_iri(node_subject)
        out = [triple(node_subject, "#{VOCAB}slt", iri: t),
               triple(t, RDF_TYPE, iri: "#{VOCAB}SLTTuple")]

        SLT_PREDICATES.each_key do |key|
          value = slt[key].to_s
          out << triple(t, "#{VOCAB}#{key}", iri: term_iri(value)) unless value.empty?
        end

        rs = slt["responsiveSignature"].to_s
        out << triple(t, "#{VOCAB}responsiveSignature", literal: rs) unless rs.empty?

        ts = slt["tokenSignature"]
        if ts.is_a?(Hash) && !ts.empty?
          sig = "#{t}/tokenSignature"
          out << triple(t, "#{VOCAB}tokenSignature", iri: sig)
          out << triple(sig, RDF_TYPE, iri: "#{VOCAB}TokenSignature")
          ts.each do |k, v|
            next if v.is_a?(Hash) || v.is_a?(Array) || v.nil? || v.to_s.empty?

            out << triple(sig, "#{VOCAB}#{k}", literal: v.to_s)
          end
        end

        out
      end
      private_class_method :slt_triples

      # One tuple per node, named from it. A content-derived name would make two
      # components with the same tuple share one node, which is a dedup decision
      # the specification does not ask for.
      def tuple_iri(node_subject) = "#{node_subject}/slt"
      private_class_method :tuple_iri

      def walk(node, parent, position, &block)
        return unless node.is_a?(Hash)

        block.call(node, parent, position)
        Array(node["children"]).each_with_index { |c, i| walk(c, node, i, &block) }
      end
      private_class_method :walk

      def triple(subject, predicate, iri: nil, literal: nil, datatype: nil)
        object = if iri
                   "<#{iri}>"
                 elsif datatype
                   %("#{escape(literal)}"^^<#{datatype}>)
                 else
                   %("#{escape(literal)}")
                 end
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
