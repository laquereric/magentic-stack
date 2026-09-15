# frozen_string_literal: true

module Vv
  module Perch
    class Step < Record
      KINDS = %w[rule judgment effect].freeze

      belongs_to :use_case, class_name: "Vv::Perch::UseCase"
      belongs_to :effect_binding, class_name: "Vv::Perch::EffectBinding", optional: true
      has_many :slice_steps, class_name: "Vv::Perch::SliceStep", dependent: :destroy

      validates :step_key, :kind, presence: true
      validates :kind, inclusion: { in: KINDS }
    end
  end
end
