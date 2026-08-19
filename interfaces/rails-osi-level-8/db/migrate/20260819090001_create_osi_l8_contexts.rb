# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8Contexts < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_contexts do |t|
      governed_columns(t)
      t.string   :subject_iri,   null: false
      t.string   :context_kind,  null: false
      t.json     :jsonld,        null: false
      t.string   :graph_iri
      t.string   :shape_id,      null: false
      t.string   :shape_digest,  null: false
      t.datetime :admitted_at,   null: false
      t.string   :supersedes_cid
    end
    governed_indexes(:osi_l8_contexts)
    add_index :osi_l8_contexts, :payload_digest, unique: true
    add_index :osi_l8_contexts, [:subject_iri, :context_kind, :admitted_at], name: "idx_osi_l8_contexts_subject_kind_time"
    add_index :osi_l8_contexts, :supersedes_cid
  end
end
