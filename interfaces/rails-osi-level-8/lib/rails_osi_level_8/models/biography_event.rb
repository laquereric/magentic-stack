# frozen_string_literal: true

module RailsOsiLevel8
  class BiographyEvent < Record
    self.table_name = "osi_l8_biography_events"
    include GovernedRecord

    EVENT_KINDS = %w[declared role_asserted capability_asserted affiliation_asserted retired].freeze

    validates :subject_iri, :event_kind, :asserted_by_iri, :statement_json, presence: true
    validates :event_kind, inclusion: { in: EVENT_KINDS }
  end
end
