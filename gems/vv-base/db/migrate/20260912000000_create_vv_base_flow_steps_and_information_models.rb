# frozen_string_literal: true

# F2 — user-flow steps and the information model they collect/present.
# Children of Flow, not a seventh canonical *kind*. Page stays derived (P9).
# Table names unprefixed, same as actors/journeys/flows (ADR 0015).
class CreateVvBaseFlowStepsAndInformationModels < ActiveRecord::Migration[7.0]
  def change
    create_table :information_models do |t|
      t.string :key, null: false
      t.string :title, null: false
      t.string :subject_type
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :information_models, :key, unique: true
    add_index :information_models, :ledger_placement

    create_table :information_fields do |t|
      t.bigint :information_model_id, null: false
      t.string :name, null: false
      t.string :datatype, null: false
      t.boolean :required, null: false, default: true
      t.string :cardinality, null: false, default: "1"
      t.string :enum_key
      t.string :meaning_concept_cid
      t.integer :ordinal, null: false
      t.timestamps
    end
    add_index :information_fields, [:information_model_id, :name],
              unique: true, name: "idx_information_fields_model_name"
    add_index :information_fields, :information_model_id

    create_table :flow_steps do |t|
      t.bigint :flow_id, null: false
      t.integer :ordinal, null: false
      t.string :step_key, null: false
      t.string :title, null: false
      t.string :kind, null: false
      t.bigint :information_model_id
      t.string :route_key
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :flow_steps, [:flow_id, :ordinal], unique: true, name: "idx_flow_steps_flow_ordinal"
    add_index :flow_steps, [:flow_id, :step_key], unique: true, name: "idx_flow_steps_flow_key"
    add_index :flow_steps, :information_model_id
    add_index :flow_steps, :ledger_placement
  end
end
