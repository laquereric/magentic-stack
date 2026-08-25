# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

# P11.3 — Profile 11 Meaning durable store. Same governed_columns as P1–P9.
class CreateOsiL8MngEntities < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  TABLES = %w[
    osi_l8_mng_concepts
    osi_l8_mng_definition_revisions
    osi_l8_mng_attestations
    osi_l8_mng_bindings
    osi_l8_mng_activations
    osi_l8_mng_receipts
    osi_l8_mng_disputes
  ].freeze

  def change
    TABLES.each do |table|
      create_table table do |t|
        governed_columns(t)
        t.json :envelope_json, null: false, default: {}
        t.integer :sequence, null: false
      end
      governed_indexes(table)
      add_index table, :sequence, name: "idx_#{table}_sequence"
    end
  end
end
