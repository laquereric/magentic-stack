# frozen_string_literal: true

module Vv
  module Perch
    class WholenessFinding < Record
      TIERS = %w[floor price symptom].freeze
      TEST_KEYS = %w[T1 T2 T3 T4 T5 T6 T7 T8].freeze

      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id

      validates :test_key, presence: true, inclusion: { in: TEST_KEYS }
      validates :tier, presence: true, inclusion: { in: TIERS }
    end
  end
end
