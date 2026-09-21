# frozen_string_literal: true

module Vv
  module DecisionObject
    # The object persists after execution rather than disappearing. That is
    # the whole claim, and it is what forces versioning and governance:
    # something that outlives its own execution can be revised, audited,
    # and eventually decommissioned.
    #
    #   designed → instantiated → executed → monitored → audited
    #                                                      ├→ revised → instantiated
    #                                                      └→ decommissioned
    module Lifecycle
      STATES = %i[designed instantiated executed monitored audited revised decommissioned].freeze

      TRANSITIONS = {
        designed: %i[instantiated decommissioned],
        instantiated: %i[executed decommissioned],
        executed: %i[monitored audited decommissioned],
        monitored: %i[audited executed decommissioned],
        audited: %i[revised decommissioned monitored],
        revised: %i[instantiated decommissioned],
        decommissioned: []
      }.freeze

      module_function

      def state?(state)
        STATES.include?(state.to_s.to_sym)
      end

      def allowed?(from, to)
        TRANSITIONS.fetch(from.to_s.to_sym, []).include?(to.to_s.to_sym)
      end

      def next_states(from)
        TRANSITIONS.fetch(from.to_s.to_sym, [])
      end

      def terminal?(state)
        next_states(state).empty?
      end

      # @return [Hash] envelope carrying the new state
      def transition(from, to)
        from = from.to_s.to_sym
        to = to.to_s.to_sym

        return Envelope.refuse(:unknown_state, "#{to} is not a lifecycle state") unless state?(to)
        return Envelope.refuse(:unknown_state, "#{from} is not a lifecycle state") unless state?(from)

        unless allowed?(from, to)
          allowed = next_states(from)
          because = allowed.empty? ? "#{from} is terminal" : "#{from} may only become #{allowed.join(', ')}"
          return Envelope.refuse(:illegal_transition, because, from: from, to: to)
        end

        Envelope.ok(data: to, from: from)
      end
    end
  end
end
