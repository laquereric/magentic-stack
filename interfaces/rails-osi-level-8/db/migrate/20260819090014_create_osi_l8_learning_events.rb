# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8LearningEvents < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_learning_events do |t|
      governed_columns(t)
      t.string :learning_cycle_id,  null: false
      t.string :event_kind,         null: false
      t.string :baseline_ref
      t.string :observed_ref
      t.string :severity
      t.string :status,             null: false
      t.string :subject_cid
      t.json   :evidence_cids,      null: false, default: []
      t.json   :proposal_json,      null: false, default: {}
      t.string :decided_by_iri
    end
    governed_indexes(:osi_l8_learning_events)
    add_index :osi_l8_learning_events, [:learning_cycle_id, :recorded_at],
              name: "idx_osi_l8_learn_cycle_time"
    add_index :osi_l8_learning_events, [:event_kind, :status],
              name: "idx_osi_l8_learn_kind_status"
    add_index :osi_l8_learning_events, :subject_cid
    add_index :osi_l8_learning_events, :baseline_ref
  end
end
