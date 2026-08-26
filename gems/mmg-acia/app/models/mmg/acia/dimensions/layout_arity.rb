# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Dimensions
      # HOW MANY the arrangement expects -- one, two, three, many.
      class LayoutArity < Dimension
        self.table_name = "acia_layout_arities"
        def self.dimension_key = "layoutArity"
      end
    end
  end
end
