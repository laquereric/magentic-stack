# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class Package < Record
      include LedgerPlaced

      has_many :definition_versions, dependent: :destroy

      validates :definition_key, presence: true, uniqueness: true
    end
  end
end
