# frozen_string_literal: true

module Vv
  module Perch
    # An edge in the freeze DAG: this freeze depends on that one.
    #
    # It has to be a DAG, not merely a graph. `cascade_from` walks it with a
    # `seen` guard so a cycle would not hang — which is worse than hanging,
    # because a cycle means the price is wrong quietly: a change to A would be
    # priced as affecting B, whose change is priced as affecting A, and no
    # ordering of "what do I have to absorb first" exists. F5 prices what sits
    # ABOVE a decision, and above is only meaningful without cycles.
    class FreezeEdge < Record
      belongs_to :rung_freeze, class_name: "Vv::Perch::Freeze", foreign_key: :freeze_id
      belongs_to :depends_on_freeze, class_name: "Vv::Perch::Freeze",
                                     foreign_key: :depends_on_freeze_id

      validate :acyclic

      private

      def acyclic
        return if freeze_id.nil? || depends_on_freeze_id.nil?

        if freeze_id == depends_on_freeze_id
          errors.add(:depends_on_freeze_id, Refusals::FREEZE_DEPENDS_ON_ITSELF)
          return
        end

        # cascade_from(X) is everything ABOVE X -- what depends on it. This edge
        # says "rung_freeze depends on depends_on_freeze", putting rung_freeze
        # above it. That closes a loop exactly when the dependency is ALREADY
        # above us. Walking from the dependency instead reads the graph
        # backwards and lets every cycle longer than a self-edge through.
        return unless Freeze.cascade_from(rung_freeze).exists?(id: depends_on_freeze_id)

        errors.add(:depends_on_freeze_id, Refusals::FREEZE_DEPENDS_ON_ITSELF)
      end
    end
  end
end
