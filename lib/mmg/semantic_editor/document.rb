# frozen_string_literal: true

require_relative "disclosure"
require_relative "canonical_id"

module Mmg
  module SemanticEditor
    # THE EDITABLE DOCUMENT.
    #
    # An ACIA tree becomes editable when two things are true of it: every node
    # that stands for something in the underlying model carries a canonical id,
    # and every node declares which disclosure tier it belongs to. This module
    # checks both, and builds the index the rest of the editor works against.
    #
    # A node WITHOUT a canonical id is not an error -- it is chrome. Panels,
    # headings and spacers exist to hold the editable nodes. They are indexed as
    # structure, not as edit targets.
    module Document
      module_function

      # The prop key a node carries its canonical id on.
      ID_KEY = "canonicalId"

      def index(acia)
        root = root_node(acia)
        return root unless root[:ok]

        entries = {}
        chrome = []
        problems = []

        walk(root[:node], nil, :immediate) do |node, parent_id, inherited_tier|
          cid = canonical_id_of(node)
          t = Disclosure.tier(node)
          tier = t[:ok] && !t[:defaulted] ? t[:tier] : inherited_tier
          problems << { node: node["id"], reason: t[:reason], because: t[:because] } if t[:ok] == false

          if cid.nil?
            chrome << node["id"]
            next tier
          end

          parsed = CanonicalId.parse(cid)
          unless parsed[:ok]
            problems << { node: node["id"], reason: parsed[:reason], because: parsed[:because] }
            next tier
          end

          if entries.key?(cid)
            problems << { node: node["id"], reason: :duplicate_canonical_id,
                          because: "#{cid} appears on more than one node (#{entries[cid][:node]} and #{node['id']})" }
            next tier
          end

          entries[cid] = {
            node: node["id"],
            canonical_id: cid,
            kind: parsed[:kind],
            tier: tier,
            parent: parent_id,
            props: node["props"] || {}
          }
          tier
        end

        { ok: true,
          entries: entries,
          chrome: chrome,
          problems: problems,
          editable: entries.reject { |_, e| CanonicalId::DERIVED_KINDS.include?(e[:kind]) }.keys,
          derived: entries.select { |_, e| CanonicalId::DERIVED_KINDS.include?(e[:kind]) }.keys }
      end

      # Is this tree fit to hand to an editor? A tree with no canonical ids at
      # all cannot be decomposed afterwards, so it is refused up front rather
      # than accepted and silently unwritable.
      def admissible?(acia)
        idx = index(acia)
        return idx unless idx[:ok]

        if idx[:entries].empty?
          return { ok: false, reason: :no_canonical_ids,
                   because: "no node carries a #{ID_KEY}; an edit to this tree could not be routed back" }
        end

        blocking = idx[:problems].reject { |p| p[:reason] == :unknown_tier }
        unless blocking.empty?
          return { ok: false, reason: :unroutable_nodes,
                   because: blocking.map { |p| "#{p[:node]}: #{p[:because]}" }.join("; "),
                   problems: blocking }
        end

        { ok: true, editable: idx[:editable], derived: idx[:derived], chrome: idx[:chrome].length }
      end

      # Everything the editor may show without opening a further tier.
      def at_tier(acia, tier)
        visible = Disclosure.visible_at(tier)
        return visible unless visible[:ok]

        idx = index(acia)
        return idx unless idx[:ok]

        { ok: true,
          tier: tier.to_s.to_sym,
          entries: idx[:entries].select { |_, e| visible[:tiers].include?(e[:tier]) } }
      end

      # What is attached to this id that the current tier is NOT showing? This
      # is the question an editor must be able to answer before saving.
      def hidden_beneath(acia, canonical_id, tier)
        idx = index(acia)
        return idx unless idx[:ok]

        anchor = idx[:entries][canonical_id.to_s]
        return { ok: false, reason: :unknown_id, because: "#{canonical_id} is not in this document" } if anchor.nil?

        hidden = idx[:entries].select do |cid, e|
          cid != anchor[:canonical_id] &&
            cid.start_with?("#{anchor[:canonical_id]}:") &&
            Disclosure.deeper?(e[:tier], tier)
        end

        { ok: true, anchor: anchor[:canonical_id], tier: tier.to_s.to_sym, hidden: hidden.keys }
      end

      def canonical_id_of(node)
        raw = node.dig("props", "valueJson", ID_KEY) || node[ID_KEY]
        s = raw.to_s.strip
        s.empty? ? nil : s
      end

      def root_node(acia)
        return { ok: false, reason: :no_document, because: "expected an ACIA document Hash" } unless acia.is_a?(Hash)

        node = acia["rootNode"] || acia["root"] || (acia.key?("id") ? acia : nil)
        return { ok: false, reason: :no_root, because: "document carries neither rootNode nor root" } if node.nil?

        { ok: true, node: node }
      end

      # Depth-first. The block returns the tier children should inherit, so a
      # sidebar panel puts its whole subtree in the sidebar without every child
      # having to repeat it.
      def walk(node, parent_id, inherited_tier, &block)
        return unless node.is_a?(Hash)

        tier = block.call(node, parent_id, inherited_tier) || inherited_tier
        Array(node["children"]).each { |c| walk(c, node["id"], tier, &block) }
      end
      private_class_method :walk
    end
  end
end
