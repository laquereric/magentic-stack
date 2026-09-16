# frozen_string_literal: true

module Vv
  module Perch
    # perchv2 §12.1. Every verdict carries its class, and the two are not
    # interchangeable: `inward` says the parts integrate, `outward` says the
    # receiver's aim was met. Only the second can finish a slice.
    class SignalReading < Record
      CLASSES = %w[inward outward].freeze

      belongs_to :outward_signal, class_name: "Vv::Perch::OutwardSignal"

      validates :signal_class, presence: true, inclusion: { in: CLASSES }
      validate :matured_at_is_not_minted_here

      def outward? = signal_class.to_s == "outward"

      # value may be NULL, and that is PENDING -- never a fail. A slice released
      # three days ago under a P7D window has no reading yet, and reading that
      # absence as an aim unmet kills a released slice inside its own window.
      def measured? = !value.nil?

      def matured?(now: Time.now.utc) = outward_signal.matured?(self, now: now)

      def matures_at = outward_signal.matures_at(self)

      private

      # Same shape as Slice#released_at_not_minted_here: the column is a record
      # of a computation, so the computation writes it. Hand-stamping it would
      # let a window be declared closed while it is open, which is the one thing
      # the window exists to prevent.
      def matured_at_is_not_minted_here
        return unless will_save_change_to_matured_at?
        return if matured_at.nil?
        return if outward_signal&.matured?(self, now: matured_at)

        errors.add(:matured_at, Refusals::SIGNAL_NOT_MATURED)
      end
    end
  end
end
