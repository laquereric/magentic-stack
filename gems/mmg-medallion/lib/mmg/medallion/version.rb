# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    # 0.3.0 -- MINOR, not patch. The engine now appends this gem's db/migrate
    # path (it never did), so every host that runs db:prepare gains a
    # `medallions` table it did not have before. That is a change to the host's
    # schema, which is not a patch-level thing to do quietly. The migration was
    # also renumbered past mind-pod's schema baseline; see the migration for why.
    VERSION = "0.3.0"
  end
end
