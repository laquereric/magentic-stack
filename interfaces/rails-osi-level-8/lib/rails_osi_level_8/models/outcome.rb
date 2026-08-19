# frozen_string_literal: true

module RailsOsiLevel8
  class Outcome < Record
    self.table_name = "osi_l8_outcomes"
    include GovernedRecord

    STATUSES = %w[achieved not_achieved unknown].freeze

    validates :effect_cid, :outcome_kind, :status, :determined_at, :determiner_iri,
              :outcome_json, presence: true
    validates :status, inclusion: { in: STATUSES }
  end
end
