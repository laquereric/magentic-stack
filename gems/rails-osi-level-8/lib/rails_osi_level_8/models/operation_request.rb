# frozen_string_literal: true

module RailsOsiLevel8
  class OperationRequest < Record
    self.table_name = "osi_l8_operation_requests"
    include GovernedRecord

    # Declared list. A POSITIVE property, never a fallback. Operations on this
    # list bypass P6; they are not "indeterminate admissions". Today: complete
    # (gap 56). Do not derive this from journal emptiness (ADR 0052).
    NOT_AN_ADMISSION_NAMES = %w[l8.execution.complete].freeze

    has_many :journal_entries,
             class_name: "RailsOsiLevel8::OperationJournalEntry",
             primary_key: :cid,
             foreign_key: :operation_request_cid
    has_one :receipt,
            class_name: "RailsOsiLevel8::ExecutionReceipt",
            primary_key: :cid,
            foreign_key: :operation_request_cid

    validates :operation_name, :direction, :idempotency_scope, :idempotency_key,
              :request_context_cid, :request_digest, presence: true
    validates :direction, inclusion: { in: %w[push] }

    # admitted = authorized AND no refused. NEVER treats response_refused as
    # refused. NEVER uses the else-branch as not_an_admission.
    scope :admitted, lambda {
      req = table_name
      journal = OperationJournalEntry.table_name
      where.not(operation_name: NOT_AN_ADMISSION_NAMES)
        .where(<<~SQL.squish)
          EXISTS (
            SELECT 1 FROM #{journal} j
            WHERE j.operation_request_cid = #{req}.cid
              AND j.event_kind = 'authorized'
          )
        SQL
        .where(<<~SQL.squish)
          NOT EXISTS (
            SELECT 1 FROM #{journal} j
            WHERE j.operation_request_cid = #{req}.cid
              AND j.event_kind = 'refused'
          )
        SQL
    }

    def admission_state
      return :not_an_admission if NOT_AN_ADMISSION_NAMES.include?(operation_name)

      kinds = journal_entries.where(event_kind: %w[authorized refused]).pluck(:event_kind)
      if kinds.include?("refused")
        :refused
      elsif kinds.include?("authorized")
        :admitted
      else
        :indeterminate
      end
    end
  end
end
