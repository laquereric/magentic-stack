# frozen_string_literal: true

module Vv
  module Perch
    class Orphan < Record
      belongs_to :release_group, class_name: "Vv::Perch::ReleaseGroup", optional: true
      has_many :parties, class_name: "Vv::Perch::OrphanParty", dependent: :destroy

      validates :kind, presence: true
      # rank_together is a T6 constraint, not a ranking column.
    end
  end
end
