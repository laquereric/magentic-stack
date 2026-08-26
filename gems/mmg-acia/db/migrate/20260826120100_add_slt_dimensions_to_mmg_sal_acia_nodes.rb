# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# acia-node -has-> its five SLT dimension values, as AR relations.
#
# NULLABLE, and that is a requirement rather than a convenience. At the time of
# writing 62 of 81 live nodes carry no role at all, and none of the roles they DO
# carry (arc, brief, friction, repo, mcb_action) is a legal SLT semanticRole --
# they are domain roles, a different axis. A NOT NULL column would force
# inventing a value for every one of them, and an invented dimension is worse
# than a missing one because it reads as a decision somebody made.
#
# `slt_semantic_role_id` is prefixed because `semantic_role` already exists on
# this table as the DOMAIN role, and is read as a string across a dozen gems. An
# association named `semantic_role` would define a method that shadows that
# attribute reader and break every one of them.
class AddSltDimensionsToMmgSalAciaNodes < ActiveRecord::Migration[8.0]
  COLUMNS = %i[
    slt_semantic_role_id
    content_role_id
    layout_kind_id
    layout_arity_id
    behavior_kind_id
  ].freeze

  def change
    COLUMNS.each do |col|
      add_column :mmg_sal_acia_nodes, col, :integer, null: true
      add_index  :mmg_sal_acia_nodes, col
    end
  end
end
