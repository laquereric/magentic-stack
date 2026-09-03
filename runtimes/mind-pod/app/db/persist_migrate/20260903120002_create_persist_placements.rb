# frozen_string_literal: true

class CreatePersistPlacements < ActiveRecord::Migration[8.0]
  def change
    create_table :persist_placements do |t|
      t.string :store, null: false
      t.text :path, null: false
      t.string :set_by, null: false
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_index :persist_placements, :store, unique: true
  end
end
