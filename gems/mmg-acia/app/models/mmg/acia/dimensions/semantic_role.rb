# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Dimensions
      # The SLT WIDGET role -- what the node behaves as (heading, button, list).
      #
      # NOT Mmg::Acia::Node#semantic_role, which holds the DOMAIN role (arc,
      # brief, friction, repo). Same word, different bounded contexts: one says
      # what a node is ABOUT, the other how it BEHAVES as UI. Merging them would
      # make those one field, and no live domain role is a legal widget role.
      class SemanticRole < Dimension
        self.table_name = "acia_slt_semantic_roles"
        def self.dimension_key = "semanticRole"
      end
    end
  end
end
