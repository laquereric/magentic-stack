# frozen_string_literal: true

module Vv
  module Perch
    class OutwardSignal < Record
      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id
      has_many :readings, class_name: "Vv::Perch::SignalReading", dependent: :destroy

      # Three states, closed. A NULL measurement is never an aim unmet.
      def maturity
        return :not_instrumented if instrumented_at.nil?
        return :reporting if readings.where.not(matured_at: nil).exists?

        :pending
      end
    end
  end
end
