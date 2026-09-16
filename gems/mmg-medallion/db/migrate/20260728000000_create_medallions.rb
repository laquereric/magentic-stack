# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# ONE Medallion AR table — canonical Bronze / Silver / Gold only (design §1).
class CreateMedallions < ActiveRecord::Migration[8.0]
  def change
    create_table :medallions do |t|
      t.string  :name,        null: false
      t.integer :rank,        null: false
      t.string  :slug,        null: false
      t.text    :description, null: false
    end

    add_index :medallions, :slug, unique: true, name: "index_medallions_on_slug_unique"
    add_index :medallions, :rank, unique: true, name: "index_medallions_on_rank_unique"
    add_index :medallions, :name, unique: true, name: "index_medallions_on_name_unique"

    add_check_constraint :medallions, "rank IN (1, 2, 3)", name: "medallions_rank_is_canonical"

    add_check_constraint :medallions, <<~SQL.squish, name: "medallions_are_canonical_tiers"
      (
        slug = 'bronze' AND name = 'Bronze' AND rank = 1 AND
        description = 'Raw / ingested data.'
      ) OR (
        slug = 'silver' AND name = 'Silver' AND rank = 2 AND
        description = 'Cleaned / conformed data.'
      ) OR (
        slug = 'gold' AND name = 'Gold' AND rank = 3 AND
        description = 'Curated / business-ready data.'
      )
    SQL
  end
end
