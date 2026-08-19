# frozen_string_literal: true

# A canonical intent home carries a ledger placement. private_local NEVER crosses a
# CPCP PULL boundary -- callers get canonical/sync_intent only. (gstack review fix #1)
module LedgerPlaced
  extend ActiveSupport::Concern
  PLACEMENTS = %w[canonical sync_intent private_local].freeze

  included do
    validates :ledger_placement, inclusion: { in: PLACEMENTS }
    scope :cross_boundary, -> { where.not(ledger_placement: "private_local") }
  end
end
