# frozen_string_literal: true

# Canonical AR homes for Mission/Vision/Persona + Journey/Flow/Actor.
# Table names match the mind-pod originals so existing databases keep working.
# ledger_placement is in the create (not a follow-up) so a new host gets the
# security column from the first migrate.
class CreateVvBaseCanonicalHomes < ActiveRecord::Migration[7.0]
  def change
    create_table :missions do |t|
      t.string :title, null: false
      t.text   :body
      t.string :status, null: false, default: "draft"
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :missions, :status
    add_index :missions, :ledger_placement

    create_table :visions do |t|
      t.string :title, null: false
      t.text   :body
      t.string :status, null: false, default: "draft"
      t.string :time_horizon
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :visions, :status
    add_index :visions, :ledger_placement

    create_table :personas do |t|
      t.string :name, null: false
      t.text   :summary
      t.string :status, null: false, default: "draft"
      t.boolean :persona_role, null: false, default: true
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :personas, :status
    add_index :personas, :ledger_placement

    create_table :actors do |t|
      t.string :name, null: false
      t.string :role_key, null: false
      t.text   :capabilities_json
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :actors, :role_key, unique: true
    add_index :actors, :ledger_placement

    create_table :journeys do |t|
      t.string :title, null: false
      t.text   :goal
      t.string :scenario
      t.string :status, null: false, default: "draft"
      t.bigint :primary_actor_id
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :journeys, :status
    add_index :journeys, :primary_actor_id
    add_index :journeys, :ledger_placement

    create_table :flows do |t|
      t.string :title, null: false
      t.text   :task_goal
      t.string :status, null: false, default: "draft"
      t.bigint :journey_id, null: false
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :flows, :journey_id
    add_index :flows, :status
    add_index :flows, :ledger_placement
  end
end
