# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# The five SLT dimensions become tables.
#
# Five tables rather than one polymorphic table because "table" is a legal
# semanticRole AND a legal layoutKind, and "timeline" likewise. Keyed by token
# alone they would collide into one row meaning two things.
class CreateAciaSltDimensions < ActiveRecord::Migration[8.0]
  TABLES = %w[
    acia_slt_semantic_roles
    acia_content_roles
    acia_layout_kinds
    acia_layout_arities
    acia_behavior_kinds
  ].freeze

  def change
    TABLES.each do |name|
      create_table name do |t|
        t.string  :token, null: false
        t.integer :ordinal, null: false, default: 0
        t.string  :registry_version, null: false, default: "ghis-19@1"
        t.text    :description
        t.timestamps
      end
      # Unique per dimension: two rows for "heading" is two answers to one question.
      add_index name, :token, unique: true
    end
  end
end
