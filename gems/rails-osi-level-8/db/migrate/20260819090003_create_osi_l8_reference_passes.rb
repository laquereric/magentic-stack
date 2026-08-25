# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8ReferencePasses < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_reference_passes do |t|
      governed_columns(t)
      t.string   :reference_id,            null: false
      t.string   :event_kind,              null: false
      t.string   :reference_uri
      t.string   :target_cid
      t.string   :target_uri
      t.string   :integrity_digest
      t.string   :issuer_iri
      t.string   :holder_iri
      t.string   :recipient_iri
      t.datetime :expires_at
      t.json     :access_descriptor_json,  null: false, default: {}
    end
    governed_indexes(:osi_l8_reference_passes)
    add_index :osi_l8_reference_passes, [:reference_id, :recorded_at], name: "idx_osi_l8_ref_pass_ref_time"
    add_index :osi_l8_reference_passes, :target_cid
    add_index :osi_l8_reference_passes, :recipient_iri
    add_index :osi_l8_reference_passes, :expires_at
  end
end
