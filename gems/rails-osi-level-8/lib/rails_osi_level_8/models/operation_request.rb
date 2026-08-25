# frozen_string_literal: true

module RailsOsiLevel8
  class OperationRequest < Record
    self.table_name = "osi_l8_operation_requests"
    include GovernedRecord

    has_many :journal_entries,
             class_name: "RailsOsiLevel8::OperationJournalEntry",
             primary_key: :cid,
             foreign_key: :operation_request_cid
    has_one :receipt,
            class_name: "RailsOsiLevel8::ExecutionReceipt",
            primary_key: :cid,
            foreign_key: :operation_request_cid

    validates :operation_name, :direction, :idempotency_scope, :idempotency_key,
              :request_context_cid, :request_digest, :admission_status, presence: true
    validates :direction, inclusion: { in: %w[push] }
    validates :admission_status, inclusion: { in: %w[admitted refused] }
  end
end
