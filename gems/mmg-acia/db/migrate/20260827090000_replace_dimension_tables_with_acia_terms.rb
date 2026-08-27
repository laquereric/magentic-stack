# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# Replace the five per-dimension tables with one term table.
#
# The Profile 9 shapes use ONE resource per term -- ux:table is legal as a
# semanticRole and as a layoutKind -- so five tables made two rows where the
# specification has one. Which enumerations admit a term is carried on the row.
#
# A NEW VERSION, not an edit of the one that created the five tables. That
# version is already recorded in schema_migrations on a live database, so
# rewriting it in place would leave the old tables standing and acia_terms never
# created, with db:migrate reporting success. A replacement has to be its own
# migration.
#
# Dropping the five is safe: they hold SEED data derived from the spec, and every
# node FK into them is NULL. The migration checks that rather than assuming it.
class ReplaceDimensionTablesWithAciaTerms < ActiveRecord::Migration[8.0]
  OLD = %w[
    acia_slt_semantic_roles acia_content_roles acia_layout_kinds
    acia_layout_arities acia_behavior_kinds
  ].freeze

  FKS = %w[
    slt_semantic_role_id content_role_id layout_kind_id layout_arity_id behavior_kind_id
  ].freeze

  def up
    create_table :acia_terms do |t|
      t.string  :token, null: false
      t.string  :enumerations, null: false, default: ""
      t.integer :ordinal, null: false, default: 0
      t.timestamps
    end
    add_index :acia_terms, :token, unique: true

    # REFUSE rather than silently orphan. If a node already points at a row in
    # the old tables, dropping them turns that reference into a dangling id --
    # so stop and let a human decide, instead of destroying the link.
    if table_exists?(:mmg_sal_acia_nodes)
      bound = FKS.select { |c| column_exists?(:mmg_sal_acia_nodes, c) }
                 .sum { |c| select_value("SELECT COUNT(*) FROM mmg_sal_acia_nodes WHERE #{c} IS NOT NULL").to_i }
      raise "#{bound} node(s) still reference the per-dimension tables; re-point them before dropping" if bound.positive?
    end

    OLD.each { |t| drop_table(t) if table_exists?(t) }
  end

  def down
    drop_table :acia_terms if table_exists?(:acia_terms)
    OLD.each do |name|
      next if table_exists?(name)

      create_table name do |t|
        t.string  :token, null: false
        t.integer :ordinal, null: false, default: 0
        t.string  :registry_version, null: false, default: "ghis-19@1"
        t.text    :description
        t.timestamps
      end
      add_index name, :token, unique: true
    end
  end
end
