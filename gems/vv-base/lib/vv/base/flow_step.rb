# frozen_string_literal: true

module Vv
  module Base
    class FlowStep < Record
      include LedgerPlaced

      KINDS = %w[inspect collect decide confirm].freeze

      belongs_to :flow, class_name: "Vv::Base::Flow"
      belongs_to :information_model, class_name: "Vv::Base::InformationModel", optional: true

      validates :ordinal, :step_key, :title, :kind, :flow_id, presence: true
      validates :kind, inclusion: { in: KINDS }
      validates :step_key, uniqueness: { scope: :flow_id }
      validates :ordinal, uniqueness: { scope: :flow_id }
      validates :information_model, presence: true, if: -> { kind == "collect" }
    end
  end
end
