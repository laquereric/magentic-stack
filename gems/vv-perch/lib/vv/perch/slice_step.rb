# frozen_string_literal: true

module Vv
  module Perch
    class SliceStep < Record
      PERFORMERS = %w[agent receiver].freeze

      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id
      belongs_to :step, class_name: "Vv::Perch::Step"

      validates :performed_by, presence: true, inclusion: { in: PERFORMERS }
    end
  end
end
