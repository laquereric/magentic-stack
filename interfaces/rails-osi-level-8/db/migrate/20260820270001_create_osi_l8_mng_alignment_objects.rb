# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

# P11.7 — SemanticAlignmentAssertion + FederationAgreement. Append-only.
class CreateOsiL8MngAlignmentObjects < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  TABLES = %w[
    osi_l8_mng_alignment_assertions
    osi_l8_mng_federation_agreements
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
