# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# Mmg::Acia::Triple -- one PROPOSED graph triple OWNED by an ACIA Node until McbApply commits it
# (epic_65 Fmcb/McbApply). Fmcb writes Triples to the ACIA tree (transaction-aware); McbApply adds
# the ACIA-stored triples to the graph on ACCEPT. Applied when the host boots the mmg-acia engine.
class CreateMmgAciaTriples < ActiveRecord::Migration[8.0]
  def change
    create_table :mmg_acia_triples do |t|
      t.bigint  :node_id                                   # Mmg::Acia::Node (mmg_sal_acia_nodes) that owns this proposed triple
      t.string  :subject,   null: false
      t.string  :predicate, null: false
      t.text    :object
      t.boolean :object_iri, null: false, default: false   # true = object is an IRI (<...>); false = literal ("...")
      t.string  :graph                                     # named graph URN
      t.timestamps
    end
    add_index :mmg_acia_triples, :node_id
    add_index :mmg_acia_triples, :subject
  end
end
