# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# The Profile 9 vocabulary as rows: 13 closed enumerations, 96 distinct terms,
# one namespace.
#
# ONE table, because the specification uses one resource per term. `table` and
# `timeline` are each legal in two enumerations; per-enumeration tables would
# make two rows where the spec has one. Which enumerations admit a term is
# carried on the row so a term can be refused in a position it is not legal in.
class CreateAciaTerms < ActiveRecord::Migration[8.0]
  def change
    create_table :acia_terms do |t|
      t.string  :token, null: false
      t.string  :enumerations, null: false, default: ""
      t.integer :ordinal, null: false, default: 0
      t.timestamps
    end
    add_index :acia_terms, :token, unique: true
  end
end
