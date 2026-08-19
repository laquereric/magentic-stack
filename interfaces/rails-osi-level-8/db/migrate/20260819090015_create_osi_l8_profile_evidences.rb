# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8ProfileEvidences < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_profile_evidences do |t|
      governed_columns(t)
      t.string :subject_cid,     null: false
      t.string :evidence_type,   null: false
      t.string :evidence_cid,    null: false
      t.string :operation_name
      t.json   :summary_json,    null: false, default: {}
    end
    governed_indexes(:osi_l8_profile_evidences)
    add_index :osi_l8_profile_evidences, [:subject_cid, :evidence_type, :evidence_cid],
              unique: true, name: "idx_osi_l8_prof_ev_subject_type_cid"
    add_index :osi_l8_profile_evidences, :evidence_cid
    add_index :osi_l8_profile_evidences, :operation_name
  end
end
