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

ActiveRecord::Schema[8.1].define(version: 2026_08_19_220002) do
  create_table "actors", force: :cascade do |t|
    t.text "capabilities_json"
    t.datetime "created_at", null: false
    t.string "ledger_placement", default: "canonical", null: false
    t.string "name", null: false
    t.string "role_key", null: false
    t.datetime "updated_at", null: false
    t.index ["ledger_placement"], name: "index_actors_on_ledger_placement"
    t.index ["role_key"], name: "index_actors_on_role_key", unique: true
  end

  create_table "flows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "journey_id", null: false
    t.string "ledger_placement", default: "canonical", null: false
    t.string "status", default: "draft", null: false
    t.text "task_goal"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["journey_id"], name: "index_flows_on_journey_id"
    t.index ["ledger_placement"], name: "index_flows_on_ledger_placement"
    t.index ["status"], name: "index_flows_on_status"
  end

  create_table "journeys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "goal"
    t.string "ledger_placement", default: "canonical", null: false
    t.bigint "primary_actor_id"
    t.string "scenario"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["ledger_placement"], name: "index_journeys_on_ledger_placement"
    t.index ["primary_actor_id"], name: "index_journeys_on_primary_actor_id"
    t.index ["status"], name: "index_journeys_on_status"
  end

  create_table "missions", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "ledger_placement", default: "canonical", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["ledger_placement"], name: "index_missions_on_ledger_placement"
    t.index ["status"], name: "index_missions_on_status"
  end

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

  create_table "osi_l8_authorization_evidences", force: :cascade do |t|
    t.string "action", null: false
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.datetime "decided_at", null: false
    t.string "decision", null: false
    t.json "evaluator_detail_json", default: {}, null: false
    t.string "evidence_digest", null: false
    t.string "ledger_placement", null: false
    t.string "operation_request_cid"
    t.string "payload_digest", null: false
    t.string "policy_ref", null: false
    t.string "principal_iri", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.json "redacted_evidence_json", default: {}, null: false
    t.string "resource_cid"
    t.string "resource_iri"
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_authorization_evidences_on_cid", unique: true
    t.index ["decision"], name: "index_osi_l8_authorization_evidences_on_decision"
    t.index ["operation_request_cid"], name: "index_osi_l8_authorization_evidences_on_operation_request_cid"
    t.index ["policy_ref"], name: "index_osi_l8_authorization_evidences_on_policy_ref"
    t.index ["principal_iri", "action", "decided_at"], name: "idx_osi_l8_authz_principal_action_time"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_authorization_evidences_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_authorization_evidences_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_authorization_evidences_ledger_placement"
  end

  create_table "osi_l8_biography_events", force: :cascade do |t|
    t.string "asserted_by_iri", null: false
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "event_kind", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.json "statement_json", null: false
    t.string "subject_iri", null: false
    t.datetime "updated_at", null: false
    t.datetime "valid_from"
    t.datetime "valid_to"
    t.index ["asserted_by_iri"], name: "index_osi_l8_biography_events_on_asserted_by_iri"
    t.index ["cid"], name: "index_osi_l8_biography_events_on_cid", unique: true
    t.index ["event_kind"], name: "index_osi_l8_biography_events_on_event_kind"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_biography_events_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_biography_events_on_provenance_cid"
    t.index ["subject_iri", "recorded_at"], name: "idx_osi_l8_bio_subject_time"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_biography_events_ledger_placement"
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

  create_table "osi_l8_learning_events", force: :cascade do |t|
    t.string "baseline_ref"
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "decided_by_iri"
    t.string "event_kind", null: false
    t.json "evidence_cids", default: [], null: false
    t.string "learning_cycle_id", null: false
    t.string "ledger_placement", null: false
    t.string "observed_ref"
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.json "proposal_json", default: {}, null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "severity"
    t.string "status", null: false
    t.string "subject_cid"
    t.datetime "updated_at", null: false
    t.index ["baseline_ref"], name: "index_osi_l8_learning_events_on_baseline_ref"
    t.index ["cid"], name: "index_osi_l8_learning_events_on_cid", unique: true
    t.index ["event_kind", "status"], name: "idx_osi_l8_learn_kind_status"
    t.index ["learning_cycle_id", "recorded_at"], name: "idx_osi_l8_learn_cycle_time"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_learning_events_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_learning_events_on_provenance_cid"
    t.index ["subject_cid"], name: "index_osi_l8_learning_events_on_subject_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_learning_events_ledger_placement"
  end

  create_table "osi_l8_observations", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "ledger_placement", null: false
    t.datetime "measured_at", null: false
    t.string "observation_kind", null: false
    t.string "observed_subject_cid"
    t.string "observed_subject_iri"
    t.string "observer_iri", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.json "quality_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "source_context_cid"
    t.string "unit_iri"
    t.datetime "updated_at", null: false
    t.json "value_json", null: false
    t.index ["cid"], name: "index_osi_l8_observations_on_cid", unique: true
    t.index ["observation_kind", "measured_at"], name: "idx_osi_l8_obs_kind_time"
    t.index ["observed_subject_cid", "measured_at"], name: "idx_osi_l8_obs_subject_time"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_observations_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_observations_on_provenance_cid"
    t.index ["source_context_cid"], name: "index_osi_l8_observations_on_source_context_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_observations_ledger_placement"
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

  create_table "osi_l8_outcomes", force: :cascade do |t|
    t.json "basis_observation_cids", default: [], null: false
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.datetime "determined_at", null: false
    t.string "determiner_iri", null: false
    t.string "effect_cid", null: false
    t.string "ledger_placement", null: false
    t.string "operation_request_cid"
    t.json "outcome_json", null: false
    t.string "outcome_kind", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "status", null: false
    t.string "supersedes_cid"
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_outcomes_on_cid", unique: true
    t.index ["effect_cid", "determined_at"], name: "idx_osi_l8_outcome_effect_time"
    t.index ["operation_request_cid"], name: "index_osi_l8_outcomes_on_operation_request_cid"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_outcomes_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_outcomes_on_provenance_cid"
    t.index ["status"], name: "index_osi_l8_outcomes_on_status"
    t.index ["supersedes_cid"], name: "index_osi_l8_outcomes_on_supersedes_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_outcomes_ledger_placement"
  end

  create_table "osi_l8_profile_evidences", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "evidence_cid", null: false
    t.string "evidence_type", null: false
    t.string "ledger_placement", null: false
    t.string "operation_name"
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "subject_cid", null: false
    t.json "summary_json", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_profile_evidences_on_cid", unique: true
    t.index ["evidence_cid"], name: "index_osi_l8_profile_evidences_on_evidence_cid"
    t.index ["operation_name"], name: "index_osi_l8_profile_evidences_on_operation_name"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_profile_evidences_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_profile_evidences_on_provenance_cid"
    t.index ["subject_cid", "evidence_type", "evidence_cid"], name: "idx_osi_l8_prof_ev_subject_type_cid", unique: true
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_profile_evidences_ledger_placement"
  end

  create_table "osi_l8_provenance_edges", force: :cascade do |t|
    t.string "activity_cid"
    t.string "agent_iri"
    t.datetime "asserted_at", null: false
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "from_cid", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "predicate", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "to_cid"
    t.string "to_iri"
    t.datetime "updated_at", null: false
    t.index ["activity_cid"], name: "index_osi_l8_provenance_edges_on_activity_cid"
    t.index ["cid"], name: "index_osi_l8_provenance_edges_on_cid", unique: true
    t.index ["from_cid", "predicate"], name: "idx_osi_l8_prov_from_pred"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_provenance_edges_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_provenance_edges_on_provenance_cid"
    t.index ["to_cid"], name: "index_osi_l8_provenance_edges_on_to_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_provenance_edges_ledger_placement"
  end

  create_table "osi_l8_reference_passes", force: :cascade do |t|
    t.json "access_descriptor_json", default: {}, null: false
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "event_kind", null: false
    t.datetime "expires_at"
    t.string "holder_iri"
    t.string "integrity_digest"
    t.string "issuer_iri"
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.string "recipient_iri"
    t.datetime "recorded_at", null: false
    t.string "reference_id", null: false
    t.string "reference_uri"
    t.string "target_cid"
    t.string "target_uri"
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_reference_passes_on_cid", unique: true
    t.index ["expires_at"], name: "index_osi_l8_reference_passes_on_expires_at"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_reference_passes_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_reference_passes_on_provenance_cid"
    t.index ["recipient_iri"], name: "index_osi_l8_reference_passes_on_recipient_iri"
    t.index ["reference_id", "recorded_at"], name: "idx_osi_l8_ref_pass_ref_time"
    t.index ["target_cid"], name: "index_osi_l8_reference_passes_on_target_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_reference_passes_ledger_placement"
  end

  create_table "osi_l8_routing_decisions", force: :cascade do |t|
    t.string "candidate_digest"
    t.string "chosen_channel_cid"
    t.string "chosen_target_iri", null: false
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "decision", null: false
    t.string "effect_cid"
    t.string "ledger_placement", null: false
    t.string "operation_request_cid", null: false
    t.string "payload_digest", null: false
    t.string "policy_ref"
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.string "reason_code", null: false
    t.datetime "recorded_at", null: false
    t.string "route_key", null: false
    t.datetime "updated_at", null: false
    t.index ["chosen_target_iri"], name: "index_osi_l8_routing_decisions_on_chosen_target_iri"
    t.index ["cid"], name: "index_osi_l8_routing_decisions_on_cid", unique: true
    t.index ["operation_request_cid", "recorded_at"], name: "idx_osi_l8_route_dec_op_time"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_routing_decisions_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_routing_decisions_on_provenance_cid"
    t.index ["route_key"], name: "index_osi_l8_routing_decisions_on_route_key"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_routing_decisions_ledger_placement"
  end

  create_table "osi_l8_routing_hops", force: :cascade do |t|
    t.string "channel_cid"
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.string "failure_code"
    t.string "from_iri", null: false
    t.integer "hop_number", null: false
    t.string "hop_status", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "routing_decision_cid", null: false
    t.datetime "started_at"
    t.string "to_iri", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_cid"], name: "index_osi_l8_routing_hops_on_channel_cid"
    t.index ["cid"], name: "index_osi_l8_routing_hops_on_cid", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_routing_hops_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_routing_hops_on_provenance_cid"
    t.index ["routing_decision_cid", "hop_number"], name: "idx_osi_l8_route_hop_dec_num", unique: true
    t.index ["to_iri"], name: "index_osi_l8_routing_hops_on_to_iri"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_routing_hops_ledger_placement"
  end

  create_table "osi_l8_ux_acia_documents", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "digest"
    t.json "envelope_json", default: {}, null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "predecessor_cid"
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_acia_documents_on_cid", unique: true
    t.index ["predecessor_cid"], name: "index_osi_l8_ux_acia_documents_on_predecessor_cid"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_acia_documents_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_acia_documents_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_acia_documents_ledger_placement"
  end

  create_table "osi_l8_ux_activations", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "envelope_json", default: {}, null: false
    t.string "head_kind", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "target_cid", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_activations_on_cid", unique: true
    t.index ["head_kind", "recorded_at"], name: "idx_osi_l8_ux_activation_head_time"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_activations_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_activations_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_activations_ledger_placement"
  end

  create_table "osi_l8_ux_actors", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "envelope_json", default: {}, null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_actors_on_cid", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_actors_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_actors_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_actors_ledger_placement"
  end

  create_table "osi_l8_ux_evidences", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "envelope_json", default: {}, null: false
    t.string "gate"
    t.string "ledger_placement", null: false
    t.string "operation_name"
    t.boolean "passed"
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_evidences_on_cid", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_evidences_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_evidences_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_evidences_ledger_placement"
  end

  create_table "osi_l8_ux_flows", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "envelope_json", default: {}, null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_flows_on_cid", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_flows_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_flows_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_flows_ledger_placement"
  end

  create_table "osi_l8_ux_interaction_events", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "envelope_json", default: {}, null: false
    t.string "event_kind"
    t.string "ledger_placement", null: false
    t.string "machine_effect_cid"
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.string "receipt_cid"
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_interaction_events_on_cid", unique: true
    t.index ["machine_effect_cid"], name: "index_osi_l8_ux_interaction_events_on_machine_effect_cid"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_interaction_events_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_interaction_events_on_provenance_cid"
    t.index ["receipt_cid", "event_kind"], name: "idx_osi_l8_ux_ix_receipt_kind"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_interaction_events_ledger_placement"
  end

  create_table "osi_l8_ux_journeys", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "envelope_json", default: {}, null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_journeys_on_cid", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_journeys_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_journeys_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_journeys_ledger_placement"
  end

  create_table "osi_l8_ux_pages", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "envelope_json", default: {}, null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_pages_on_cid", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_pages_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_pages_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_pages_ledger_placement"
  end

  create_table "osi_l8_ux_receipts", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.json "envelope_json", default: {}, null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_receipts_on_cid", unique: true
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_receipts_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_receipts_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_receipts_ledger_placement"
  end

  create_table "osi_l8_ux_token_sets", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "digest"
    t.json "envelope_json", default: {}, null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "predecessor_cid"
    t.string "profile_id", null: false
    t.string "provenance_cid"
    t.json "provenance_json", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cid"], name: "index_osi_l8_ux_token_sets_on_cid", unique: true
    t.index ["predecessor_cid"], name: "index_osi_l8_ux_token_sets_on_predecessor_cid"
    t.index ["profile_id", "ledger_placement", "recorded_at"], name: "idx_osi_l8_ux_token_sets_profile_ledger_time"
    t.index ["provenance_cid"], name: "index_osi_l8_ux_token_sets_on_provenance_cid"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_ux_token_sets_ledger_placement"
  end

  create_table "osi_level_8_intent_constraints", force: :cascade do |t|
    t.string "cid", null: false
    t.string "constraint_status", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "ledger_placement", null: false
    t.string "name", null: false
    t.text "normative_statement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.index ["cid"], name: "idx_osi_l8_i_constraints_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_constraints_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_constraints_ledger_placement"
  end

  create_table "osi_level_8_intent_economic_actors", force: :cascade do |t|
    t.string "actor_kind", null: false
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "external_identifier"
    t.string "ledger_placement", null: false
    t.string "name", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.index ["cid"], name: "idx_osi_l8_i_economic_actors_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_economic_actors_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_economic_actors_ledger_placement"
  end

  create_table "osi_level_8_intent_exchange_relationships", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "exchange_kind", null: false
    t.string "exchange_status", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.text "summary", null: false
    t.index ["cid"], name: "idx_osi_l8_i_exchange_relationships_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_exchange_relationships_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_exchange_relationships_ledger_placement"
  end

  create_table "osi_level_8_intent_externalities", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "externality_polarity", null: false
    t.text "externality_statement", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.index ["cid"], name: "idx_osi_l8_i_externalities_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_externalities_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_externalities_ledger_placement"
  end

  create_table "osi_level_8_intent_goals", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "goal_status", null: false
    t.string "kind", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.date "target_date"
    t.string "title", null: false
    t.index ["cid"], name: "idx_osi_l8_i_goals_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_goals_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_goals_ledger_placement"
  end

  create_table "osi_level_8_intent_key_results", force: :cascade do |t|
    t.string "cid", null: false
    t.string "comparison", null: false
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "result_status", null: false
    t.string "state", default: "draft", null: false
    t.string "target_unit", null: false
    t.string "target_value", null: false
    t.string "title", null: false
    t.index ["cid"], name: "idx_osi_l8_i_key_results_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_key_results_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_key_results_ledger_placement"
  end

  create_table "osi_level_8_intent_market_segments", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "definition_statement", null: false
    t.string "kind", null: false
    t.string "ledger_placement", null: false
    t.string "name", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.index ["cid"], name: "idx_osi_l8_i_market_segments_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_market_segments_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_market_segments_ledger_placement"
  end

  create_table "osi_level_8_intent_offers", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "ledger_placement", null: false
    t.string "name", null: false
    t.string "offer_kind", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.index ["cid"], name: "idx_osi_l8_i_offers_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_offers_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_offers_ledger_placement"
  end

  create_table "osi_level_8_intent_outcomes", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "ledger_placement", null: false
    t.datetime "observed_at", null: false
    t.string "outcome_polarity", null: false
    t.text "outcome_statement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.index ["cid"], name: "idx_osi_l8_i_outcomes_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_outcomes_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_outcomes_ledger_placement"
  end

  create_table "osi_level_8_intent_stakeholders", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "ledger_placement", null: false
    t.string "name", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "stake_statement", null: false
    t.string "stakeholder_kind", null: false
    t.string "state", default: "draft", null: false
    t.index ["cid"], name: "idx_osi_l8_i_stakeholders_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_stakeholders_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_stakeholders_ledger_placement"
  end

  create_table "osi_level_8_intent_value_metrics", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "desired_direction", null: false
    t.string "ledger_placement", null: false
    t.string "metric_dimension", null: false
    t.string "name", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.string "unit", null: false
    t.index ["cid"], name: "idx_osi_l8_i_value_metrics_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_value_metrics_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_value_metrics_ledger_placement"
  end

  create_table "osi_level_8_intent_value_propositions", force: :cascade do |t|
    t.string "cid", null: false
    t.datetime "created_at", null: false
    t.string "ledger_placement", null: false
    t.string "payload_digest", null: false
    t.string "profile_id", default: "osi-level-8/profile-10", null: false
    t.string "proposition_status", null: false
    t.string "provenance_actor_cid"
    t.string "provenance_source_cid"
    t.string "state", default: "draft", null: false
    t.string "value_statement", null: false
    t.index ["cid"], name: "idx_osi_l8_i_value_propositions_cid", unique: true
    t.index ["ledger_placement", "state"], name: "idx_osi_l8_i_value_propositions_ledger_state"
    t.check_constraint "ledger_placement IN ('canonical','sync_intent','private_local')", name: "chk_osi_l8_i_value_propositions_ledger_placement"
  end

  create_table "personas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ledger_placement", default: "canonical", null: false
    t.string "name", null: false
    t.boolean "persona_role", default: true, null: false
    t.string "status", default: "draft", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["ledger_placement"], name: "index_personas_on_ledger_placement"
    t.index ["status"], name: "index_personas_on_status"
  end

  create_table "reconciliations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "note_count", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "visions", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "ledger_placement", default: "canonical", null: false
    t.string "status", default: "draft", null: false
    t.string "time_horizon"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["ledger_placement"], name: "index_visions_on_ledger_placement"
    t.index ["status"], name: "index_visions_on_status"
  end
end
