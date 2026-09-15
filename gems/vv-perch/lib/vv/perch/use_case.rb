# frozen_string_literal: true

module Vv
  module Perch
    class UseCase < Record
      PLACEMENTS = %w[canonical sync_intent private_local].freeze

      has_many :steps, class_name: "Vv::Perch::Step", dependent: :destroy
      has_many :slices, class_name: "Vv::Perch::Slice", dependent: :destroy
      has_many :effect_bindings, class_name: "Vv::Perch::EffectBinding", dependent: :destroy

      belongs_to :primary_actor, class_name: "Vv::Base::Actor",
                                 foreign_key: :primary_actor_id, optional: true

      validates :uc_id, :text_sha256, presence: true
      validates :uc_id, uniqueness: true
      validates :ledger_placement, inclusion: { in: PLACEMENTS }
      validates :text_sha256, format: { with: /\Asha256:[0-9a-f]{64}\z/ }
    end
  end
end
