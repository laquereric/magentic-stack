# frozen_string_literal: true

module Vv
  module Perch
    class Freeze < Record
      RUNGS = (0..4).to_a.freeze

      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id
      has_many :edges, class_name: "Vv::Perch::FreezeEdge", foreign_key: :freeze_id,
                       inverse_of: :rung_freeze, dependent: :destroy
      has_many :dependencies, through: :edges, source: :depends_on_freeze

      validates :rung, presence: true, inclusion: { in: RUNGS }
      validate :subject_is_not_a_draft

      # O2: no draft namespace. A freeze names a released artifact.
      DRAFT_MARK = /(?:^|[.\-\/_])draft(?:$|[.\-\/_])/i

      def subject_is_not_a_draft
        ref = subject_ref.to_s
        return if ref.empty?
        return unless DRAFT_MARK.match?(ref) || ref.end_with?("-draft")

        errors.add(:subject_ref, Refusals::DRAFT_NAMESPACE_UNDECIDED)
      end
      private :subject_is_not_a_draft

      # Current cascade cost is a QUERY, never a column. cost_shown_at_climb
      # is the record of what the climber was shown; it is never recomputed.
      def self.cascade_from(freeze)
        seen = {}
        walk = lambda do |id|
          return if seen[id]

          seen[id] = true
          FreezeEdge.where(depends_on_freeze_id: id).find_each do |edge|
            walk.call(edge.freeze_id)
          end
        end
        walk.call(freeze.id)
        seen.delete(freeze.id)
        where(id: seen.keys)
      end
    end
  end
end
