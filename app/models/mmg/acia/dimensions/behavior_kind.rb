# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Dimensions
      # What the node DOES -- static, disclose, navigate, collect_effect.
      class BehaviorKind < Dimension
        self.table_name = "acia_behavior_kinds"
        def self.dimension_key = "behaviorKind"
      end
    end
  end
end
