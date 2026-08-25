# frozen_string_literal: true
module RailsOsiLevel8
  # The three-ledger discipline (base OSI Level 8): canonical (shareable truth Cyborg reads),
  # sync_intent (allow-listed submitted Effect), private_local (local-only, must not cross the
  # boundary). Placement is a property of each record, enforced before admission.
  module Ledger
    CANONICAL     = :canonical
    SYNC_INTENT   = :sync_intent
    PRIVATE_LOCAL = :private_local
    ALL = [CANONICAL, SYNC_INTENT, PRIVATE_LOCAL].freeze
    module_function
    def crosses_boundary?(placement) = placement.to_sym != PRIVATE_LOCAL
  end
end
