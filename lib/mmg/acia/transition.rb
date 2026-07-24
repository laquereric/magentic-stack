# frozen_string_literal: true

require "json"
require "securerandom"
require "digest"
require_relative "state"

module Mmg
  module Acia
    # Phase B — candidate state transition (research §1.4).
    # Allow-listed semantic actions; optimistic revision; never-raise envelopes.
    module Transition
      ACTIONS = %w[select deselect toggle_pressed inspect].freeze

      module_function

      # Select a Tab by entity_token within a tree hash. Ensures exclusive selection
      # under the containing TabList. Returns candidate tree + revision metadata.
      def select_tab(tree, entity_token:, expected_revision: nil)
        return refused(:invalid_tree, "tree must be a Hash") unless tree.is_a?(::Hash)

        rev = tree_revision(tree)
        if expected_revision && !expected_revision.to_s.empty? && expected_revision.to_s != rev
          return {
            ok: false,
            reason: :revision_conflict,
            because: "expected_tree_revision #{expected_revision.inspect} != current #{rev.inspect}",
            current_revision: rev,
            refreshable: true
          }
        end

        candidate = deep_dup(tree)
        target = find_node(candidate) { |n| State.send(:entity_token, n) == entity_token.to_s }
        return refused(:unknown_token, "no node for entity_token=#{entity_token}") unless target
        return refused(:not_a_tab, "node role is not tab") unless State.send(:role_of, target) == "tab"

        # Find nearest tablist ancestor and exclusivity-clear siblings
        tablist = find_tablist_ancestor(candidate, target)
        if tablist
          State.send(:children_of, tablist).each do |child|
            next unless State.send(:role_of, child) == "tab"
            set_state!(child, "selected" => (State.send(:entity_token, child) == entity_token.to_s))
          end
        else
          set_state!(target, "selected" => true)
        end

        topo = State.validate_tree(candidate)
        new_rev = tree_revision(candidate)
        {
          ok: true,
          action: "select",
          entity_token: entity_token.to_s,
          prior_revision: rev,
          tree_revision: new_rev,
          candidate: candidate,
          topology: topo,
          topology_conforms: topo[:conforms] == true
        }
      rescue ::StandardError => e
        refused(:transition_failed, "#{e.class}: #{e.message}")
      end

      def tree_revision(tree)
        # Stable content digest of kind/role/token/state (not AR ids).
        payload = flatten_for_rev(tree).to_json
        "r_#{::Digest::SHA256.hexdigest(payload)[0, 12]}"
      end

      def allowed_actions_for(node)
        role = State.send(:role_of, node)
        case role
        when "tab" then [{ "name" => "select", "requires_revision" => true }]
        when "toggle" then [{ "name" => "toggle_pressed", "requires_revision" => true }]
        else [{ "name" => "inspect", "requires_revision" => false }]
        end
      end

      def refused(reason, because)
        { ok: false, reason: reason, because: because.to_s }
      end

      def deep_dup(obj)
        case obj
        when ::Hash
          obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
        when ::Array
          obj.map { |v| deep_dup(v) }
        else
          obj
        end
      end

      def find_node(node, &block)
        return node if node.is_a?(::Hash) && yield(node)
        return nil unless node.is_a?(::Hash)
        State.send(:children_of, node).each do |child|
          found = find_node(child, &block)
          return found if found
        end
        nil
      end

      def find_tablist_ancestor(root, target)
        path = []
        locate = lambda do |node, stack|
          return false unless node.is_a?(::Hash)
          stack.push(node)
          if node.equal?(target) || State.send(:entity_token, node) == State.send(:entity_token, target)
            path.replace(stack.dup)
            return true
          end
          State.send(:children_of, node).each do |c|
            return true if locate.call(c, stack)
          end
          stack.pop
          false
        end
        locate.call(root, [])
        path.reverse.find { |n| State.send(:role_of, n) == "tablist" }
      end

      def set_state!(node, **kv)
        st = State.send(:state_of, node).merge(kv.transform_keys(&:to_s))
        if node.key?(:semantic_state) || !node.key?("semantic_state")
          node[:semantic_state] = st
        end
        node["semantic_state"] = st if node.key?("semantic_state") || !node.key?(:semantic_state)
        st
      end

      def flatten_for_rev(node, acc = [])
        return acc unless node.is_a?(::Hash)
        acc << [
          node[:kind] || node["kind"],
          node[:semantic_role] || node["semantic_role"],
          State.send(:entity_token, node),
          State.send(:state_of, node)
        ]
        State.send(:children_of, node).each { |c| flatten_for_rev(c, acc) }
        acc
      end

      private_class_method :refused, :deep_dup, :find_node, :find_tablist_ancestor,
                           :set_state!, :flatten_for_rev
    end
  end
end
