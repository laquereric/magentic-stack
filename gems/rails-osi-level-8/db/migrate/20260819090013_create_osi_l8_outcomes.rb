# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8Outcomes < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_outcomes do |t|
      governed_columns(t)
      t.string   :effect_cid,               null: false
      t.string   :operation_request_cid
      t.string   :outcome_kind,             null: false
      t.string   :status,                   null: false
      t.datetime :determined_at,            null: false
      t.string   :determiner_iri,           null: false
      t.json     :outcome_json,             null: false
      t.json     :basis_observation_cids,   null: false, default: []
      t.string   :supersedes_cid
    end
    governed_indexes(:osi_l8_outcomes)
    add_index :osi_l8_outcomes, [:effect_cid, :determined_at], name: "idx_osi_l8_outcome_effect_time"
    add_index :osi_l8_outcomes, :operation_request_cid
    add_index :osi_l8_outcomes, :status
    add_index :osi_l8_outcomes, :supersedes_cid
  end
end
