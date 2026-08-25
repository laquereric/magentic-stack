# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

# P9.6 — Profile 9 GHIS durable store. Same governed columns + ledger check as P1–P8.
class CreateOsiL8UxEntities < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  TABLES = {
    osi_l8_ux_actors: ->(t) {},
    osi_l8_ux_journeys: ->(t) {},
    osi_l8_ux_flows: ->(t) {},
    osi_l8_ux_pages: ->(t) {},
    osi_l8_ux_acia_documents: ->(t) {
      t.string :predecessor_cid
      t.string :digest
    },
    osi_l8_ux_token_sets: ->(t) {
      t.string :predecessor_cid
      t.string :digest
    },
    osi_l8_ux_interaction_events: ->(t) {
      t.string :receipt_cid
      t.string :event_kind
      t.string :machine_effect_cid
    },
    osi_l8_ux_receipts: ->(t) {},
    osi_l8_ux_evidences: ->(t) {
      t.string :operation_name
      t.string :gate
      t.boolean :passed
    },
    osi_l8_ux_activations: ->(t) {
      t.string :head_kind, null: false
      t.string :target_cid, null: false
    }
  }.freeze

  def change
    TABLES.each do |table, extra|
      create_table table do |t|
        governed_columns(t)
        t.json :envelope_json, null: false, default: {}
        extra.call(t)
      end
      governed_indexes(table)
    end

    add_index :osi_l8_ux_token_sets, :predecessor_cid
    add_index :osi_l8_ux_acia_documents, :predecessor_cid
    add_index :osi_l8_ux_interaction_events, [:receipt_cid, :event_kind],
              name: "idx_osi_l8_ux_ix_receipt_kind"
    add_index :osi_l8_ux_interaction_events, :machine_effect_cid
    add_index :osi_l8_ux_activations, [:head_kind, :recorded_at],
              name: "idx_osi_l8_ux_activation_head_time"
  end
end
