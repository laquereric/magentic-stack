# frozen_string_literal: true

module RailsOsiLevel8
  class RoutingDecision < Record
    self.table_name = "osi_l8_routing_decisions"
    include GovernedRecord

    DECISIONS = %w[routed rejected deferred].freeze

    validates :route_key, :operation_request_cid, :chosen_target_iri, :decision, :reason_code,
              presence: true
    validates :decision, inclusion: { in: DECISIONS }
  end
end
