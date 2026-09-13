# frozen_string_literal: true

module Vv
  module Base
    # Canonical Flow home — shared by P9 GHIS and P10 INTENT. Not ux_flows / intent_flows.
    class Flow < Record
      include LedgerPlaced
      belongs_to :journey, class_name: "Vv::Base::Journey"
      has_many :steps, class_name: "Vv::Base::FlowStep", inverse_of: :flow, dependent: :destroy

      validates :title, :status, :journey_id, presence: true
      validates :status, inclusion: { in: %w[draft active archived] }
      validate :active_flow_has_steps

      private

      def active_flow_has_steps
        return unless status == "active"
        return if steps.reject(&:marked_for_destruction?).any?

        errors.add(:steps, "active_flow_requires_steps")
      end
    end
  end
end
