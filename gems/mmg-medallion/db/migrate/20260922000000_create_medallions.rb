# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# ONE Medallion AR table — canonical Bronze / Silver / Gold only (design §1).
#
# RENUMBERED from 20260728000000. Appending this engine's migration path (see
# engine.rb) is necessary but not sufficient: mind-pod's db/schema.rb carries
# version 2026_09_12_000000, and `db:prepare` on a fresh database LOADS that
# schema and then calls assume_migrated_upto_version, which records every
# migration older than the baseline as already applied. At 20260728000000 this
# one would be marked run without its table ever being created -- the same
# reason vv-perch and vv-per-site, which post-date the baseline, do get created
# at boot.
#
# Renumbering past the baseline is safe here in a way it usually is not: no host
# can have this version in schema_migrations, because until engine.rb was fixed no
# host was ever offered the migration at all. It now runs at boot exactly like the
# vv-perch and vv-per-site tables already do, all of which post-date the same
# stale baseline.
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
