# frozen_string_literal: true

module RailsOsiLevel8
  class RoutingHop < Record
    self.table_name = "osi_l8_routing_hops"
    include GovernedRecord

    HOP_STATUSES = %w[attempted delivered failed].freeze

    validates :routing_decision_cid, :hop_number, :from_iri, :to_iri, :hop_status, presence: true
    validates :hop_status, inclusion: { in: HOP_STATUSES }
  end
end
