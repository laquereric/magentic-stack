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
    # The eight kinds ADR 0052 names. response_refused was in the ADR and in the
    # adapter (cpcp_adapter.rb writes it when a RESPONSE fails its shape) but not
    # here, so that write raised RecordInvalid, the adapter's outer rescue turned
    # it into processing_failed, and the caller was told the wrong thing about
    # the wrong layer.
    #
    # response_refused is NOT refused: one is a refused response, the other a
    # refused admission. OperationRequest derives admission from an explicit
    # where(event_kind: %w[authorized refused]), so adding this kind cannot widen
    # what counts as a refused admission.
    EVENT_KINDS = %w[
      received grounded authorized refused response_refused routed dispatched completed
    ].freeze

    validates :event_kind, inclusion: { in: EVENT_KINDS }
  end
end
