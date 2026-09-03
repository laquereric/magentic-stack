# This file is auto-generated from the current state of the PERSIST database. It
# holds the tables owned by ROLE=persist on the persist-data volume
# (PERSIST_DB_PATH), separate from the domain sqlite it places. See
# docs/architecture/GAP8.md.

ActiveRecord::Schema[8.1].define(version: 2026_09_03_120002) do
  create_table "persist_placements", force: :cascade do |t|
    t.string "store", null: false
    t.text "path", null: false
    t.string "set_by", null: false
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store"], name: "index_persist_placements_on_store", unique: true
  end
end
