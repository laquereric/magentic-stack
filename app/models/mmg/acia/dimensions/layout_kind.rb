# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Dimensions
      # How children are ARRANGED -- stack, grid, split.
      class LayoutKind < Dimension
        self.table_name = "acia_layout_kinds"
        def self.dimension_key = "layoutKind"
      end
    end
  end
end
