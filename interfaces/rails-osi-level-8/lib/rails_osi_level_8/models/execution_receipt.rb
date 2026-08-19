# frozen_string_literal: true

module RailsOsiLevel8
  class ExecutionReceipt < Record
    self.table_name = "osi_l8_execution_receipts"
    include GovernedRecord

    belongs_to :operation_request,
               class_name: "RailsOsiLevel8::OperationRequest",
               primary_key: :cid,
               foreign_key: :operation_request_cid,
               optional: true

    validates :operation_request_cid, :execution_key, :status, :completed_at, presence: true
    validates :status, inclusion: { in: %w[succeeded failed refused] }
  end
end
