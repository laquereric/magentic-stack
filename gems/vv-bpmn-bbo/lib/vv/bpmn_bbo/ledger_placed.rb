# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

require "active_support/concern"

module Vv
  module BpmnBbo
    # Same placement vocab as Vv::Base::LedgerPlaced. Copied so this gem
    # does not require vv-base at runtime.
    module LedgerPlaced
      extend ActiveSupport::Concern
      PLACEMENTS = %w[canonical sync_intent private_local].freeze

      included do
        validates :ledger_placement, inclusion: { in: PLACEMENTS }
        scope :cross_boundary, -> { where.not(ledger_placement: "private_local") }
      end
    end
  end
end
