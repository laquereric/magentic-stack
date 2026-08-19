# frozen_string_literal: true

module RailsOsiLevel8
  class ReferencePass < Record
    self.table_name = "osi_l8_reference_passes"
    include GovernedRecord

    EVENT_KINDS = %w[issued passed accepted revoked expired].freeze

    validates :reference_id, :event_kind, :access_descriptor_json, presence: true
    validates :event_kind, inclusion: { in: EVENT_KINDS }
  end
end
