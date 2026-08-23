# frozen_string_literal: true

module Mmg
  module SemanticEditor
    # WHAT IS SHOWN, AND WHEN.
    #
    # An editable ACIA tree carries more than the page shows at rest. The same
    # document holds what is immediately visible, what appears on hover, what
    # opens in a sidebar, and what is only reached by asking. Those are not four
    # documents -- they are one document with four disclosure tiers.
    #
    # This matters for an EDITOR specifically: a person editing only the
    # immediate tier can silently orphan detail that still exists at a deeper
    # tier. So the tier is part of the node, and the editor can always answer
    # "what else is attached to this that I am not looking at?"
    module Disclosure
      module_function

      # Ordered shallowest to deepest. The order is meaningful: a tier may only
      # be reached through the tiers above it.
      TIERS = %i[immediate hover sidebar detail].freeze

      DEFAULT = :immediate

      # The prop key a node carries its tier on.
      KEY = "disclosureTier"

      def tier(node)
        return refuse(:no_node, "expected a node Hash") unless node.is_a?(Hash)

        raw = node.dig("props", "valueJson", KEY) || node[KEY]
        return { ok: true, tier: DEFAULT, defaulted: true } if raw.nil?

        t = raw.to_s.to_sym
        return refuse(:unknown_tier, "#{raw.inspect} is not one of #{TIERS.join(', ')}") unless TIERS.include?(t)

        { ok: true, tier: t, defaulted: false }
      end

      def depth(t)
        i = TIERS.index(t.to_s.to_sym)
        return refuse(:unknown_tier, "#{t.inspect} is not a disclosure tier") if i.nil?

        { ok: true, tier: t.to_s.to_sym, depth: i }
      end

      # Is `inner` deeper than `outer`? Used to detect a node whose detail is
      # hidden beneath the tier currently being edited.
      def deeper?(inner, outer)
        a = depth(inner)
        b = depth(outer)
        return false unless a[:ok] && b[:ok]

        a[:depth] > b[:depth]
      end

      # Everything at or above a tier -- what an editor working at `t` can see
      # without opening anything further.
      def visible_at(t)
        d = depth(t)
        return d unless d[:ok]

        { ok: true, tiers: TIERS[0..d[:depth]] }
      end

      RULE = "A tier is part of the node, not of the view. An editor that cannot name " \
             "what is attached below the tier it is showing will orphan it."

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
