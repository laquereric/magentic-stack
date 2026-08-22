# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # R3 — host layout *decision* (no CSS here). The browser host
    # (data/osi-level-8/ux-host-layout.js) applies scoped rules. The renderer
    # and vv-html-components do not.
    module HostLayout
      module_function

      def arity_ok?(arity, count)
        case arity.to_s
        when "one" then count == 1
        when "two" then count == 2
        when "three" then count == 3
        when "many" then count >= 4
        else false
        end
      end

      def recipe_for(signature)
        sig = signature.to_s
        sig = "default" if sig.empty?
        Vocabulary::RESPONSIVE_RECIPES[sig]
      end

      # Returns { "apply" => bool, "reason" => ..., "recipe" => ..., "signature" => ... }
      def decide(layout_kind:, layout_arity:, responsive_signature:, participating_child_count:)
        count = participating_child_count.to_i
        unless arity_ok?(layout_arity, count)
          return { "apply" => false, "reason" => "arity", "fallback" => "flow" }
        end

        kind = layout_kind.to_s
        kind = "stack" if kind.empty? || !Acia::LAYOUT_KINDS.include?(kind)

        recipe = recipe_for(responsive_signature)
        unless recipe
          return { "apply" => false, "reason" => "unknown-signature", "fallback" => "flow" }
        end

        family = recipe["family"].to_s
        if family == "flow" || responsive_signature.to_s.empty? || responsive_signature.to_s == "default"
          return { "apply" => false, "reason" => "safe-generic", "fallback" => "flow", "recipe" => recipe }
        end
        if family != kind
          return { "apply" => false, "reason" => "family-mismatch", "fallback" => "flow" }
        end
        if recipe["childCount"] && recipe["childCount"] != count
          return { "apply" => false, "reason" => "child-count", "fallback" => "flow" }
        end

        { "apply" => true, "recipe" => recipe, "signature" => responsive_signature.to_s, "childCount" => count }
      end

      def participating_children(node)
        Array(node.is_a?(Hash) ? node["children"] : nil).select { |c| c.is_a?(Hash) && !c["nodeId"].to_s.empty? }
      end

      def board_container_slt(doc)
        walk = lambda { |n|
          return nil unless n.is_a?(Hash)
          return n["slt"] if n["nodeId"].to_s == "brd-board-1"
          Array(n["children"]).each { |c|
            found = walk.call(c)
            return found if found
          }
          nil
        }
        walk.call(doc.is_a?(Hash) ? (doc["root"] || doc["rootNode"]) : nil)
      end
    end
  end
end
