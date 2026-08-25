# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

# P11.6 — artifact log. Existing DefinitionRevision.content is copied here;
# revision rows are not rewritten (append-only).
class CreateOsiL8MngNormativeArtifacts < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_mng_normative_artifacts do |t|
      governed_columns(t)
      t.json :envelope_json, null: false, default: {}
      t.integer :sequence, null: false
    end
    governed_indexes("osi_l8_mng_normative_artifacts")
    add_index :osi_l8_mng_normative_artifacts, :sequence, name: "idx_osi_l8_mng_normative_artifacts_sequence"
  end
end
