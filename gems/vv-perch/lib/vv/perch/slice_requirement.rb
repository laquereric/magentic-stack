# frozen_string_literal: true

module Vv
  module Perch
    class SliceRequirement < Record
      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id
      belongs_to :requires_slice, class_name: "Vv::Perch::Slice",
                                  foreign_key: :requires_slice_id

      validate :requires_is_acyclic

      private

      def requires_is_acyclic
        return if slice_id.nil? || requires_slice_id.nil?

        if slice_id == requires_slice_id || reaches?(requires_slice_id, slice_id)
          errors.add(:requires_slice_id, Refusals::T5)
        end
      end

      def reaches?(from_id, target_id, seen = {})
        return false if from_id.nil?
        return true if from_id == target_id
        return false if seen[from_id]

        seen[from_id] = true
        self.class.where(slice_id: from_id).pluck(:requires_slice_id).any? do |nxt|
          reaches?(nxt, target_id, seen)
        end
      end
    end
  end
end
