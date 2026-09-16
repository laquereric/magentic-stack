# frozen_string_literal: true

module Vv
  module Perch
    # One half of a shared decision. §11.3's parties carry the item, the team
    # that owns it, and the board it is visible on -- "visible on both boards"
    # is an obligation, and a party with no board cannot discharge it.
    class OrphanParty < Record
      belongs_to :orphan, class_name: "Vv::Perch::Orphan"

      validates :item_ref, presence: true
      validates :owner_team, presence: true
      validates :board, presence: true

      # §11.3 convergence is computed from these. Nil is honest -- "we have not
      # measured this team's cycle time" -- and Orphan#convergence says so
      # rather than assuming zero, which would claim the two items converge
      # today.
      validates :cycle_time_p85_days,
                numericality: { only_integer: true, greater_than: 0 },
                allow_nil: true
    end
  end
end
