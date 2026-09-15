# frozen_string_literal: true

module Vv
  module Perch
    # Owner calls O1–O4, closed 2026-09-15. Named so a gate can plant them.
    module Doctrine
      # O1: advisory slices whose effects are all by_receiver need no envelope
      # and no Gate. Automated effects stay BACK (ADR 0056).
      BY_RECEIVER_IN_GOVERNANCE = true

      # O2: no care.v8-draft analogue. Freeze only released LinkML artifacts.
      DRAFT_NAMESPACE = nil

      # O3: NOOA is pinned upstream, never forked into this gem.
      NOOA_FORK_REFUSED = true

      # O4: a use case is shareable truth unless an overlay opts into private_local.
      DEFAULT_PLACEMENT = "canonical"
    end
  end
end
