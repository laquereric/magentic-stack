# frozen_string_literal: true

# P10.M1 — canonical AR homes for Mission/Vision/Persona + Journey/Flow/Actor.
# NOT intent_*-prefixed. Profile nuance + relationships stay in the RDF graph (later).
class CreateCanonicalIntentHomes < ActiveRecord::Migration[8.0]
  def change
    create_table :missions do |t|
      t.string :title, null: false
      t.text   :body
      t.string :status, null: false, default: "draft"
      t.timestamps
    end
    add_index :missions, :status

    create_table :visions do |t|
      t.string :title, null: false
      t.text   :body
      t.string :status, null: false, default: "draft"
      t.string :time_horizon
      t.timestamps
    end
    add_index :visions, :status

    # Canonical persona home (standing in for mmg-site Cohort typed as Persona).
    # Not intent_personas — one AR home only.
    create_table :personas do |t|
      t.string :name, null: false
      t.text   :summary
      t.string :status, null: false, default: "draft"
      t.boolean :persona_role, null: false, default: true
      t.timestamps
    end
    add_index :personas, :status

    create_table :actors do |t|
      t.string :name, null: false
      t.string :role_key, null: false
      t.text   :capabilities_json
      t.timestamps
    end
    add_index :actors, :role_key, unique: true

    create_table :journeys do |t|
      t.string :title, null: false
      t.text   :goal
      t.string :scenario
      t.string :status, null: false, default: "draft"
      t.bigint :primary_actor_id
      t.timestamps
    end
    add_index :journeys, :status
    add_index :journeys, :primary_actor_id

    create_table :flows do |t|
      t.string :title, null: false
      t.text   :task_goal
      t.string :status, null: false, default: "draft"
      t.bigint :journey_id, null: false
      t.timestamps
    end
    add_index :flows, :journey_id
    add_index :flows, :status
  end
end
