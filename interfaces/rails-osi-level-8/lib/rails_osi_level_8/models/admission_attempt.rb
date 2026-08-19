# frozen_string_literal: true

module RailsOsiLevel8
  class AdmissionAttempt < Record
    self.table_name = "osi_l8_admission_attempts"
    include GovernedRecord

    validates :operation_name, :direction, :request_digest, presence: true
    validates :conforms, inclusion: { in: [true, false] }
    validate :must_be_private_local

    private

    def must_be_private_local
      return if ledger_placement == "private_local"

      errors.add(:ledger_placement, "admission attempts must be private_local")
    end
  end
end
