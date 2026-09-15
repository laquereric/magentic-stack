# frozen_string_literal: true

class CreateVvPerch < ActiveRecord::Migration[7.0]
  def change
    create_table :perch_release_groups do |t|
      t.string :group_key, null: false
      t.datetime :released_at
      t.timestamps
    end
    add_index :perch_release_groups, :group_key, unique: true

    create_table :perch_use_cases do |t|
      t.string :uc_id, null: false
      t.string :text_sha256, null: false
      t.string :level
      t.text :aim
      t.integer :primary_actor_id
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :perch_use_cases, :uc_id, unique: true
    add_index :perch_use_cases, :ledger_placement

    create_table :perch_effect_bindings do |t|
      t.references :use_case, null: false, foreign_key: { to_table: :perch_use_cases }
      t.string :effect_ref, null: false
      t.integer :responsible_id
      t.string :mode, null: false
      t.timestamps
    end
    add_index :perch_effect_bindings, [:use_case_id, :effect_ref], unique: true,
              name: "idx_perch_effect_bindings_uc_ref"

    create_table :perch_steps do |t|
      t.references :use_case, null: false, foreign_key: { to_table: :perch_use_cases }
      t.string :step_key, null: false
      t.string :kind, null: false
      t.references :effect_binding, foreign_key: { to_table: :perch_effect_bindings }
      t.timestamps
    end
    add_index :perch_steps, [:use_case_id, :step_key], unique: true

    create_table :perch_slices do |t|
      t.references :use_case, null: false, foreign_key: { to_table: :perch_use_cases }
      t.string :slice_key, null: false
      t.string :title
      t.integer :receiver_id
      t.text :terminates_at
      t.string :entry_method
      t.references :release_group, foreign_key: { to_table: :perch_release_groups }
      t.datetime :gate_passed_at
      t.datetime :released_at
      t.timestamps
    end
    add_index :perch_slices, [:use_case_id, :slice_key], unique: true

    create_table :perch_slice_steps do |t|
      t.references :slice, null: false, foreign_key: { to_table: :perch_slices }
      t.references :step, null: false, foreign_key: { to_table: :perch_steps }
      t.string :performed_by, null: false
      t.timestamps
    end
    add_index :perch_slice_steps, [:slice_id, :step_id], unique: true

    create_table :perch_slice_requirements do |t|
      t.references :slice, null: false, foreign_key: { to_table: :perch_slices }
      t.integer :requires_slice_id, null: false
      t.timestamps
    end
    add_foreign_key :perch_slice_requirements, :perch_slices, column: :requires_slice_id
    add_index :perch_slice_requirements, [:slice_id, :requires_slice_id], unique: true,
              name: "idx_perch_slice_requirements_pair"

    create_table :perch_outward_signals do |t|
      t.references :slice, null: false, foreign_key: { to_table: :perch_slices }
      t.text :text
      t.string :metric
      t.string :source
      t.string :delay_iso8601
      t.datetime :instrumented_at
      t.timestamps
    end

    create_table :perch_signal_readings do |t|
      t.references :outward_signal, null: false, foreign_key: { to_table: :perch_outward_signals }
      t.string :signal_class, null: false
      t.string :value
      t.datetime :observed_at
      t.datetime :matured_at
      t.timestamps
    end

    create_table :perch_wholeness_findings do |t|
      t.references :slice, null: false, foreign_key: { to_table: :perch_slices }
      t.string :test_key, null: false
      t.string :tier, null: false
      t.text :finding
      t.text :suggested_resolution
      t.string :status
      t.timestamps
    end
    add_index :perch_wholeness_findings, [:slice_id, :test_key]

    create_table :perch_freezes do |t|
      t.references :slice, null: false, foreign_key: { to_table: :perch_slices }
      t.integer :rung, null: false
      t.string :subject_kind
      t.string :subject_ref
      t.integer :climbed_by_id
      t.datetime :climbed_at
      t.text :cost_shown_at_climb
      t.timestamps
    end
    add_index :perch_freezes, [:slice_id, :rung]

    create_table :perch_freeze_edges do |t|
      t.references :freeze, null: false, foreign_key: { to_table: :perch_freezes }
      t.integer :depends_on_freeze_id, null: false
      t.timestamps
    end
    add_foreign_key :perch_freeze_edges, :perch_freezes, column: :depends_on_freeze_id
    add_index :perch_freeze_edges, [:freeze_id, :depends_on_freeze_id], unique: true,
              name: "idx_perch_freeze_edges_pair"

    create_table :perch_orphans do |t|
      t.string :kind, null: false
      t.text :frozen_decision
      t.text :could_be_overturned_by
      t.string :common_parent
      t.references :release_group, foreign_key: { to_table: :perch_release_groups }
      t.boolean :rank_together, null: false, default: false
      t.integer :standing_owner_id
      t.string :status
      t.timestamps
    end

    create_table :perch_orphan_parties do |t|
      t.references :orphan, null: false, foreign_key: { to_table: :perch_orphans }
      t.string :item_ref
      t.string :owner_team
      t.string :board
      t.timestamps
    end

    create_table :perch_methods do |t|
      t.references :slice, null: false, foreign_key: { to_table: :perch_slices }
      t.string :name, null: false
      t.string :mode, null: false
      t.string :strategy
      t.integer :rung
      t.string :prod_binding_ref
      t.timestamps
    end
    add_index :perch_methods, [:slice_id, :name], unique: true
  end
end
