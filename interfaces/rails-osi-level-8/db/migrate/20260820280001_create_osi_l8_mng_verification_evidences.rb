# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

# P11.8 — SemanticVerificationEvidence. Append-only.
class CreateOsiL8MngVerificationEvidences < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_mng_verification_evidences do |t|
      governed_columns(t)
      t.json :envelope_json, null: false, default: {}
      t.integer :sequence, null: false
    end
    governed_indexes("osi_l8_mng_verification_evidences")
    add_index :osi_l8_mng_verification_evidences, :sequence, name: "idx_osi_l8_mng_verification_evidences_sequence"
  end
end
