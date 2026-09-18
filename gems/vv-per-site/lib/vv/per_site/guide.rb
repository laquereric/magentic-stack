# frozen_string_literal: true

module Vv
  module PerSite
    # Walks the OKF tree for a particular site. Each internal node is a
    # question (its children are the answers); each CTA leaf looks up the
    # site's registered Call To Action. Never raises.
    class Guide
      attr_reader :site, :bundle_key

      def initialize(site:)
        @site = site
        @bundle_key = site.bundle_key
      end

      def root
        node = OkfNode.in_bundle(bundle_key).roots.first
        return { ok: false, reason: :no_bundle, because: "no OKF nodes for #{bundle_key}" } unless node

        { ok: true, node: node, options: options_for(node), cta: cta_for(node) }
      end

      def at(okf_path)
        node = OkfNode.in_bundle(bundle_key).find_by(okf_path: okf_path.to_s)
        return { ok: false, reason: :unknown_path, because: okf_path.to_s } unless node

        { ok: true, node: node, options: options_for(node), cta: cta_for(node) }
      end

      def choose(from_path, child_path)
        parent = OkfNode.in_bundle(bundle_key).find_by(okf_path: from_path.to_s)
        return { ok: false, reason: :unknown_path, because: from_path.to_s } unless parent

        child = parent.children.find_by(okf_path: child_path.to_s)
        return { ok: false, reason: :not_a_child, because: child_path.to_s } unless child

        { ok: true, node: child, options: options_for(child), cta: cta_for(child) }
      end

      def options_for(node)
        node.children.order(:position, :id).map do |child|
          {
            path: child.okf_path,
            title: child.title,
            kind: child.kind,
            description: child.description,
            cta_leaf: child.cta_leaf?
          }
        end
      end

      def cta_for(node)
        return nil unless node.cta_leaf?

        site.ctas.find_by(okf_node_id: node.id)
      end
    end
  end
end
