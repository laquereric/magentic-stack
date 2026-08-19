# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_19_090017) do
  create_table "notes", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "osi_l8_admission_attempts", force: :cascade do |t|
    t.string "caller_iri"
    t.string "cid", null: false
    t.boolean "conforms", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "ledger_placement", null: false
    t.string "operation_name", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "refusal_reason"
    t.json "report_json", default: {}, null: false
    t.string "request_cid"
    t.string "request_digest", null: false
    t.string "shape_digest"
    t.string "shape_id"
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_admission_attempts_on_cid", unique: true
    t.index ["conforms"], name: "index_osi_l8_admission_attempts_on_conforms"
    t.index ["operation_name", "recorded_at"], name: "idx_osi_l8_admission_op_time"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_admission_attempts_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_admission_attempts_on_provenance_cid"
    t.index ["request_cid"], name: "index_osi_l8_admission_attempts_on_request_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_admission_attempts_ledger_placement"
  end

  create_table "osi_l8_contexts", force: :cascade do |t|
    t.datetime "admitted_at", null: false
    t.string "cid", null: false
    t.string "context_kind", null: false
    t.datetime "created_at", null: false
    t.string "graph_iri"
    t.json "jsonld", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "shape_digest", null: false
    t.string "shape_id", null: false
    t.string "subject_iri", null: false
    t.string "supersedes_cid"
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_contexts_on_cid", unique: true
    t.index ["payload_digest"], name: "index_osi_l8_contexts_on_payload_digest", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_contexts_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_contexts_on_provenance_cid"
    t.index ["subject_iri", "context_kind", "admitted_at"], name: "idx_osi_l8_contexts_subject_kind_time"
    t.index ["supersedes_cid"], name: "index_osi_l8_contexts_on_supersedes_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_contexts_ledger_placement"
  end

  create_table "osi_l8_cyborg_channels", force: :cascade do |t|
    t.json "capabilities_json", default: {}, null: false
    t.string "channel_key", null: false
    t.string "channel_status", null: false
    t.string "cid", null: false
    t.string "contract_context_cid"
    t.string "counterparty_iri"
    t.datetime "created_at", null: false
    t.string "cyborg_iri", null: false
    t.string "direction", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "transport", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_cyborg_channels_on_cid", unique: true
    t.index ["contract_context_cid"], name: "index_osi_l8_cyborg_channels_on_contract_context_cid"
    t.index ["cyborg_iri", "channel_key", "payload_digest"], name: "idx_osi_l8_channels_cyborg_key_digest", unique: true
    t.index ["cyborg_iri", "recorded_at"], name: "idx_osi_l8_channels_cyborg_time"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_cyborg_channels_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_cyborg_channels_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_cyborg_channels_ledger_placement"
  end

  create_table "osi_l8_execution_receipts", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.string "effect_cid"
    t.string "execution_key", null: false
    t.string "failure_reason"
    t.string "ledger_placement", null: false
    t.string "operation_request_cid", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "replayed_from_receipt_cid"
    t.string "result_context_cid"
    t.string "result_digest"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_execution_receipts_on_cid", unique: true
    t.index ["completed_at"], name: "index_osi_l8_execution_receipts_on_completed_at"
    t.index ["effect_cid"], name: "index_osi_l8_execution_receipts_on_effect_cid"
    t.index ["execution_key"], name: "index_osi_l8_execution_receipts_on_execution_key", unique: true
    t.index ["operation_request_cid"], name: "index_osi_l8_execution_receipts_on_operation_request_cid", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_execution_receipts_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_execution_receipts_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_execution_receipts_ledger_placement"
  end

  create_table "osi_l8_operation_journal_entries", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "detail_json", default: {}, null: false
    t.datetime "event_at", null: false
    t.string "event_kind", null: false
    t.string "ledger_placement", null: false
    t.string "operation_request_cid", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.string "receipt_cid"
    t.datetime "recorded_at", null: false
    t.integer "sequence", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_operation_journal_entries_on_cid", unique: true
    t.index ["event_kind"], name: "index_osi_l8_operation_journal_entries_on_event_kind"
    t.index ["operation_request_cid", "event_at"], name: "idx_osi_l8_journal_req_time"
    t.index ["operation_request_cid", "sequence"], name: "idx_osi_l8_journal_req_seq", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_operation_journal_entries_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_operation_journal_entries_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_operation_journal_entries_ledger_placement"
  end

  create_table "osi_l8_operation_requests", force: :cascade do |t|
    t.string "admission_status", null: false
    t.string "caller_iri"
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "effect_cid"
    t.string "idempotency_key", null: false
    t.string "idempotency_scope", null: false
    t.string "ledger_placement", null: false
    t.string "operation_name", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "request_context_cid", null: false
    t.string "request_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_operation_requests_on_cid", unique: true
    t.index ["effect_cid"], name: "index_osi_l8_operation_requests_on_effect_cid"
    t.index ["operation_name", "idempotency_scope", "idempotency_key"], name: "idx_osi_l8_op_req_idempotency", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_operation_requests_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_operation_requests_on_provenance_cid"
    t.index ["request_context_cid"], name: "index_osi_l8_operation_requests_on_request_context_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_operation_requests_ledger_placement"
  end

  create_table "reconciliations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "note_count", default: 0, null: false
    t.datetime "updated_at", null: false
  end
end
