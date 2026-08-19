# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8Observations < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_observations do |t|
      governed_columns(t)
      t.string   :observed_subject_cid
      t.string   :observed_subject_iri
      t.string   :observation_kind,    null: false
      t.datetime :measured_at,         null: false
      t.string   :observer_iri,        null: false
      t.json     :value_json,          null: false
      t.string   :unit_iri
      t.string   :source_context_cid
      t.json     :quality_json,        null: false, default: {}
    end
    governed_indexes(:osi_l8_observations)
    add_index :osi_l8_observations, [:observed_subject_cid, :measured_at],
              name: "idx_osi_l8_obs_subject_time"
    add_index :osi_l8_observations, [:observation_kind, :measured_at],
              name: "idx_osi_l8_obs_kind_time"
    add_index :osi_l8_observations, :source_context_cid
  end
end
