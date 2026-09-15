# frozen_string_literal: true

module Vv
  module Perch
    class SignalReading < Record
      CLASSES = %w[inward outward].freeze

      belongs_to :outward_signal, class_name: "Vv::Perch::OutwardSignal"

      validates :signal_class, presence: true, inclusion: { in: CLASSES }

      # value may be NULL. That is pending, never a fail.
    end
  end
end
