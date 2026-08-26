# frozen_string_literal: true

module Mmg
  module Adr
    # The minimum standard, made checkable:
    #
    #   every significant decision has an ADR;
    #   every ADR points to the mechanism that enforces it;
    #   every mechanism points to the place in the code it governs.
    #
    # If any link is missing you should be able to say exactly where the chain
    # breaks -- so this returns the broken link by name rather than a boolean.
    # A bare true/false would tell you that something is wrong and leave you to
    # find out what, which is the position the wiki diagram already puts you in.
    #
    # Pure. `exists` is injected so the same code runs over a real tree in the
    # ingest path and over a fixture in a spec.
    module Chain
      module_function

      DECISION   = :decision
      CONSTRAINT = :constraint
      CODE       = :code

      # Ordered: the first missing link is the one worth reporting, because a
      # decision with no enforcement cannot have a mechanism pointing at code.
      def break_at(attrs, exists: ->(_p) { true })
        attrs = attrs.each_pair.to_h { |k, v| [k.to_s, v] }

        return DECISION   if blank?(attrs["title"]) || blank?(attrs["status"])
        return CONSTRAINT if Array(attrs["enforced_by"]).empty?
        return CODE       if Array(attrs["paths"]).empty?

        nil
      end

      def complete?(attrs, exists: ->(_p) { true })
        break_at(attrs, exists: exists).nil?
      end

      # A dead ADR is worse than no ADR: it stays inside an agent's search reach
      # and is obeyed with full mechanical consequence after the code it governs
      # has moved. So a record whose declared paths no longer resolve is a
      # finding, reported here rather than left for a reader to notice.
      def dangling(attrs, exists:)
        attrs = attrs.each_pair.to_h { |k, v| [k.to_s, v] }
        (Array(attrs["paths"]) + Array(attrs["enforced_by"])).reject { |p| exists.call(p) }
      end

      def blank?(value) = value.nil? || value.to_s.strip.empty?
    end
  end
end
