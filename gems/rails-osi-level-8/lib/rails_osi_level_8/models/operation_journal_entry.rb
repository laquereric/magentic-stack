# frozen_string_literal: true

module RailsOsiLevel8
  class OperationJournalEntry < Record
    self.table_name = "osi_l8_operation_journal_entries"
    include GovernedRecord

    belongs_to :operation_request,
               class_name: "RailsOsiLevel8::OperationRequest",
               primary_key: :cid,
               foreign_key: :operation_request_cid,
               optional: true

    validates :operation_request_cid, :sequence, :event_kind, :event_at, presence: true
    validates :event_kind, inclusion: {
      in: %w[received grounded authorized routed dispatched completed refused]
    }
  end
end
