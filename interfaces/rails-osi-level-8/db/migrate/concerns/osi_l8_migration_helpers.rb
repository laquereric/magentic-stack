# frozen_string_literal: true

module OsiL8MigrationHelpers
  def governed_columns(t)
    t.string   :cid,              null: false
    t.string   :profile_id,       null: false
    t.string   :ledger_placement, null: false
    t.string   :provenance_cid
    t.json     :provenance_json,  null: false, default: {}
    t.string   :payload_digest,   null: false
    t.datetime :recorded_at,      null: false
    t.timestamps null: false
  end

  def governed_indexes(table)
    add_index table, :cid, unique: true
    add_index table, [:profile_id, :ledger_placement, :recorded_at], name: "idx_#{table}_profile_ledger_time"
    add_index table, :provenance_cid
    add_check_constraint table,
      "ledger_placement IN ('canonical','sync_intent','private_local')",
      name: "chk_#{table}_ledger_placement"
  end
end
