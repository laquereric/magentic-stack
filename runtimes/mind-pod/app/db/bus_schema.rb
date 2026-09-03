# This file is auto-generated from the current state of the BUS database. It
# holds the tables owned by ROLE=bus on the bus-data volume (BUS_DB_PATH),
# separate from the domain sqlite (db/schema.rb). See docs/plans/bus-independent-sqlite.md.

ActiveRecord::Schema[8.1].define(version: 2026_09_03_120001) do
  create_table "bus_projections", force: :cascade do |t|
    t.string "source", null: false
    t.text "payload_json", null: false
    t.datetime "projected_at", null: false
    t.timestamps
  end
  add_index "bus_projections", ["projected_at"], name: "index_bus_projections_on_projected_at"
end
