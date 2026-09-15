# frozen_string_literal: true

module Vv
  module Perch
    class EffectBinding < Record
      MODES = %w[by_receiver per_instance envelope simulated_only].freeze

      belongs_to :use_case, class_name: "Vv::Perch::UseCase"
      belongs_to :responsible, class_name: "Vv::Base::Actor",
                               foreign_key: :responsible_id, optional: true
      has_many :steps, class_name: "Vv::Perch::Step"

      validates :effect_ref, :mode, presence: true
      validates :mode, inclusion: { in: MODES }
      # No executor column. No credential column. BACK is the gate (R1).
    end
  end
end
