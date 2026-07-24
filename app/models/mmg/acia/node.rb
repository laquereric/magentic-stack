# frozen_string_literal: true

require "json"

module Mmg
  module Acia
    # Node -- the ACIA tree as an AR HIERARCHY (epic_65 core, moved verbatim from
    # Mmg::Sal::AciaNode). Each node is a persisted ACIA node (kind/value/entity_iri/
    # semantic_role); the tree is a materialized-path hierarchy via the `ancestry` gem.
    # The GRAPH DECORATES each node with its component + styling so the TMUX / WEB / LLM
    # hosts all drive the SAME node. This is the CORE tree primitive; presentation
    # (unix_tree/dom) lives in mmg-sal, which depends on this gem.
    #
    # Table + iri + vocab kept as mmg_sal_acia_nodes / urn:mmg:sal:acia:<id> / urn:mm:*sal#
    # for ZERO-DATA-RISK continuity (plan open-Q1); the acia# rename is a later isolated
    # migration. isolate_namespace would prefix mmg_acia_ -- overridden below.
    #
    # Graph: TripleModel statements (AR-grounded). publish! still routes N-Triples through
    # Mmg::Acia::Graph (SAL public graph facade). to_triples = statements.map(&:to_nt).
    class Node < ::ActiveRecord::Base
      has_ancestry orphan_strategy: :destroy

      self.table_name = "mmg_sal_acia_nodes"

      # epic_65 Fmcb/McbApply: a node OWNS its PROPOSED triples until McbApply commits them to the graph.
      has_many :triples, class_name: "Mmg::Acia::Triple", foreign_key: "node_id", dependent: :destroy

      RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
      VOCAB    = "urn:mm:grammar:sal#"
      GRAPH    = "urn:mmg:sal:public"

      # semantic_role (a bare literal) -> an acia: role CLASS IRI so a SHACL
      # sh:targetClass can bind (epic_65 SHACL validation, non-enforcing). Unmapped
      # roles fall back to acia:Node. The LIVE roles today (arc/epic/plan/concept/
      # friction/brief/diff/file/repo/class/triple) are DOMAIN roles with no ARIA-widget
      # analogue -> acia:Node; the ARIA-widget names below bind once an ACIA tree emits
      # them. See Mmg::Acia::Shapes + lib/mmg/acia/acia_shapes.ttl.
      ACIA_VOCAB = "urn:mm:vocab/acia#"
      ROLE_IRI = {
        "button"  => "#{ACIA_VOCAB}Button",
        "heading" => "#{ACIA_VOCAB}Heading",
        "tablist" => "#{ACIA_VOCAB}TabList",
        "tab"     => "#{ACIA_VOCAB}Tab",
        "toggle"  => "#{ACIA_VOCAB}Toggle",
        "image"   => "#{ACIA_VOCAB}Image",
      }.freeze
      DEFAULT_ROLE_IRI = "#{ACIA_VOCAB}Node"

      validates :kind, presence: true

      scope :for_tree, ->(k) { where(tree_key: k) }

      def self.graph_iri = GRAPH

      def iri
        "urn:mmg:sal:acia:#{id}"
      end

      # Build a persisted AR HIERARCHY from a render-tree hash (recursive). tree_key groups
      # the nodes; position preserves sibling order. Returns the root.
      def self.materialize(node, tree_key:, parent: nil, position: 0)
        return nil unless node.is_a?(::Hash)
        rec = create!(
          tree_key:      tree_key,
          parent:        parent,
          position:      position,
          kind:          (node[:kind] || node["kind"]).to_s,
          value:         (node[:value] || node["value"]).to_s,
          entity_iri:    (node[:entity_iri] || node["entity_iri"]).to_s,
          semantic_role: (node[:semantic_role] || node["semantic_role"]).to_s,
          sal_component: (node[:sal_component] || node["sal_component"] || default_component(node)).to_s,
          styling:       serialize_styling(node[:styling] || node["styling"]),
          hint:          (node[:hint] || node["hint"]).to_s
        )
        ::Kernel.Array(node[:children] || node["children"]).each_with_index do |child, i|
          materialize(child, tree_key: tree_key, parent: rec, position: i)
        end
        rec
      end

      # Rebuild a render hash from this AR subtree (feeds the renderers).
      def to_render_node
        { kind: kind, value: value, entity_iri: entity_iri, semantic_role: semantic_role,
          hint: hint, sal_component: sal_component,
          children: children.order(:position).map(&:to_render_node) }
      end

      if defined?(::Vv::Graph::TripleModel)
        include ::Vv::Graph::TripleModel

        def graph_subject = iri

        class_triple(:owl_class, predicate: RDF_TYPE, iri: true) {
          "http://www.w3.org/2002/07/owl#Class"
        }
        triple(:rdf_type_base, predicate: RDF_TYPE, iri: true) { "urn:mm:vocab/sal#AciaNode" }
        triple(:rdf_type_role, predicate: RDF_TYPE, iri: true) {
          ROLE_IRI.fetch(semantic_role.to_s.strip.downcase, DEFAULT_ROLE_IRI)
        }
        triple(:kind,       predicate: "#{VOCAB}kind")      { kind.presence }
        triple(:value,      predicate: "#{VOCAB}value")     { value.presence }
        triple(:role,       predicate: "#{VOCAB}role")      { semantic_role.presence }
        triple(:tree_key,   predicate: "#{VOCAB}treeKey")   { tree_key.presence }
        triple(:component,  predicate: "#{VOCAB}component") { sal_component.presence }
        triple(:styling,    predicate: "#{VOCAB}styling")   { styling.presence }
        triple(:hint,       predicate: "#{VOCAB}hint")      { hint.presence }
        triple(:entity_iri, predicate: "#{VOCAB}entityIri") { entity_iri.presence }
        triple(:position,   predicate: "#{VOCAB}position")  { position.nil? ? nil : position.to_s }
        triple(:parent,     predicate: "#{VOCAB}parent", iri: true) { parent&.iri }

        # N-Triples for Mmg::Acia::Graph.publish (back-compat with SAL facade).
        def to_triples = statements.map(&:to_nt)
      else
        # Fallback when TripleModel unmounted: prior hand N-Triples.
        def to_triples
          s = "<#{iri}>"
          t = ["#{s} <#{RDF_TYPE}> <urn:mm:vocab/sal#AciaNode> ."]
          t << "#{s} <#{RDF_TYPE}> <#{ROLE_IRI.fetch(semantic_role.to_s.strip.downcase, DEFAULT_ROLE_IRI)}> ."
          { "kind" => kind, "value" => value, "role" => semantic_role, "treeKey" => tree_key,
            "component" => sal_component, "styling" => styling, "hint" => hint,
            "entityIri" => entity_iri, "position" => position.to_s }.each do |p, v|
            next if v.to_s.empty?
            t << "#{s} <#{VOCAB}#{p}> \"#{lit(v)}\" ."
          end
          t << "#{s} <#{VOCAB}parent> <#{parent.iri}> ." if parent
          t
        end

        def lit(v)
          v.to_s.gsub("\\", "\\\\").gsub('"', '\\"').gsub("\n", '\\n').gsub("\r", '\\r').gsub("\t", '\\t')
        end
      end

      # Publish this node's decoration to the public graph. Never-raise.
      def publish!
        return { ok: false, reason: :graph_unmounted } unless defined?(::Mmg::Acia::Graph)
        ::Mmg::Acia::Graph.publish(to_triples, graph: GRAPH)
      rescue ::StandardError => e
        { ok: false, reason: :publish_failed, because: "#{e.class}: #{e.message}" }
      end

      # Publish every node of a tree (bulk graph decoration). Never-raise.
      def self.publish_tree!(tree_key)
        for_tree(tree_key).map(&:publish!)
      end

      # Idempotent DELIVERY of a render-tree hash: clear any prior nodes+graph for this
      # tree_key, materialize the AR hierarchy, publish the graph decoration. The AR tree is
      # the DURABLE anchor (survives restart -> re-deliverable on cold start); the graph is
      # re-derivable. Returns the root node, or nil. Never-raise.
      def self.deliver_tree!(tree, tree_key:)
        return nil unless tree.is_a?(::Hash)
        clear_tree!(tree_key)
        root = materialize(tree, tree_key: tree_key)
        publish_tree!(tree_key) if root
        root
      rescue ::StandardError
        nil
      end

      # Remove a tree's AR nodes AND its graph subjects (so a re-delivery does not accumulate).
      def self.clear_tree!(tree_key)
        subjects = for_tree(tree_key).pluck(:id).map { |i| "urn:mmg:sal:acia:#{i}" }
        for_tree(tree_key).destroy_all
        subjects.each { |s| (::Mmg::Acia::Graph.update("DELETE WHERE { <#{s}> ?p ?o }", graph: GRAPH) rescue nil) }
      rescue ::StandardError
        nil
      end

      # The MCB action an affordance triggers, resolved from the materialized ActionComponent
      # node's binding (entity_iri urn:mm:action:<action>) within this tree_key. AR-anchored
      # read (graph is decoration; AR is truth). nil if unbound/absent.
      def self.action_for(tree_key, affordance)
        node = for_tree(tree_key).where(kind: "action")
                                 .where("LOWER(value) = ?", affordance.to_s.strip.downcase).first
        return nil unless node && node.entity_iri.to_s.start_with?("urn:mm:action:")
        node.entity_iri.sub("urn:mm:action:", "")
      rescue ::StandardError
        nil
      end

      # Default component by node kind -- which dual-mode component owns it.
      def self.default_component(node)
        case (node[:kind] || node["kind"]).to_s
        when "action"       then "ActionComponent"
        when "entity_token" then "EntityTokenComponent"
        when "list"         then "ListComponent"
        when "pane"         then "PaneComponent"
        else                     "TextComponent"
        end
      end

      def self.serialize_styling(v)
        return nil if v.nil?
        v.is_a?(::String) ? v : (::JSON.generate(v) rescue v.to_s)
      end
    end
  end
end
