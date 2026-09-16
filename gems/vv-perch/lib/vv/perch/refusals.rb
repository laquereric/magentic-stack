# frozen_string_literal: true

module Vv
  module Perch
    # Floor tests T1–T5. Closed. Named after the finding, not the mechanism.
    module Refusals
      T1 = "receiver_did_not_predate_the_cut"
      T2 = "terminating_aim_is_not_outward"
      T3 = "siblings_must_be_deletable"
      T4 = "business_naming_missing"
      T5 = "slices_are_one_whole"

      RELEASE = "release_not_minted_here"
      DRAFT_NAMESPACE_UNDECIDED = "draft_namespace_undecided"
      PIN_NEVER_FORK = "pin_never_fork"

      # Stage 2. The outward signal is the only evidence that a receiver's aim
      # was met, so the ways it can fail to be that are named too.
      INWARD_IS_NOT_OUTWARD = "inward_is_not_outward"
      SIGNAL_DELAY_UNPARSEABLE = "signal_delay_unparseable"
      SIGNAL_NOT_MATURED = "signal_not_matured"

      # Stage 3. F5 prices a change before it is accepted, so the ways that
      # pricing can be faked or skipped are named.
      FREEZE_DEPENDS_ON_ITSELF = "freeze_depends_on_itself"
      COST_SHOWN_IS_A_RECORD = "cost_shown_is_a_record"
      CLIMB_NOT_MINTED_HERE = "climb_not_minted_here"

      FLOOR = {
        t1: T1,
        t2: T2,
        t3: T3,
        t4: T4,
        t5: T5
      }.freeze

      ALL = (FLOOR.values + [RELEASE, DRAFT_NAMESPACE_UNDECIDED, PIN_NEVER_FORK,
                             INWARD_IS_NOT_OUTWARD, SIGNAL_DELAY_UNPARSEABLE,
                             SIGNAL_NOT_MATURED, FREEZE_DEPENDS_ON_ITSELF,
                             COST_SHOWN_IS_A_RECORD, CLIMB_NOT_MINTED_HERE]).freeze
    end
  end
end
