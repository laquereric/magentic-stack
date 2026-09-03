# frozen_string_literal: true

class CreateBusProjections < ActiveRecord::Migration[8.0]
  def change
    create_table :bus_projections do |t|
      t.string :source, null: false
      t.text :payload_json, null: false
      t.datetime :projected_at, null: false
      t.timestamps
    end
    add_index :bus_projections, :projected_at
  end
end
