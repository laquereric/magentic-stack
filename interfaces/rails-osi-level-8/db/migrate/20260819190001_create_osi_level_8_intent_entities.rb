# frozen_string_literal: true

# P10.M2 — Profile 10 INTENT socio-economic entity tables (append-only).
# Governed columns differ from P1–P8 helpers: state + created_at, no updated_at.
class CreateOsiLevel8IntentEntities < ActiveRecord::Migration[8.0]
  PROFILE_DEFAULT = "osi-level-8/profile-10"
  LEDGER_CHECK = "ledger_placement IN ('canonical','sync_intent','private_local')"

  TABLES = {
    osi_level_8_intent_stakeholders: ->(t) {
      t.string :name, null: false
      t.string :stakeholder_kind, null: false
      t.string :stake_statement, null: false
    },
    osi_level_8_intent_value_propositions: ->(t) {
      t.string :value_statement, null: false
      t.string :proposition_status, null: false
    },
    osi_level_8_intent_offers: ->(t) {
      t.string :name, null: false
      t.string :offer_kind, null: false
      t.text :description, null: false
    },
    osi_level_8_intent_market_segments: ->(t) {
      t.string :name, null: false
      t.string :kind, null: false
      t.string :definition_statement, null: false
    },
    osi_level_8_intent_economic_actors: ->(t) {
      t.string :name, null: false
      t.string :actor_kind, null: false
      t.string :external_identifier
    },
    osi_level_8_intent_exchange_relationships: ->(t) {
      t.string :exchange_kind, null: false
      t.string :exchange_status, null: false
      t.text :summary, null: false
    },
    osi_level_8_intent_goals: ->(t) {
      t.string :title, null: false
      t.string :kind, null: false
      t.date :target_date
      t.string :goal_status, null: false
    },
    osi_level_8_intent_key_results: ->(t) {
      t.string :title, null: false
      t.string :target_value, null: false
      t.string :comparison, null: false
      t.string :target_unit, null: false
      t.datetime :due_at
      t.string :result_status, null: false
    },
    osi_level_8_intent_outcomes: ->(t) {
      t.text :outcome_statement, null: false
      t.string :outcome_polarity, null: false
      t.datetime :observed_at, null: false
    },
    osi_level_8_intent_value_metrics: ->(t) {
      t.string :name, null: false
      t.string :metric_dimension, null: false
      t.string :unit, null: false
      t.string :desired_direction, null: false
    },
    osi_level_8_intent_constraints: ->(t) {
      t.string :name, null: false
      t.string :kind, null: false
      t.text :normative_statement, null: false
      t.string :constraint_status, null: false
    },
    osi_level_8_intent_externalities: ->(t) {
      t.text :externality_statement, null: false
      t.string :externality_polarity, null: false
    }
  }.freeze

  def change
    TABLES.each do |table, intrinsic|
      create_table table do |t|
        governed_columns(t)
        intrinsic.call(t)
      end
      governed_indexes(table)
    end
  end

  private

  def governed_columns(t)
    t.string :cid, null: false
    t.string :profile_id, null: false, default: PROFILE_DEFAULT
    t.string :ledger_placement, null: false
    t.string :state, null: false, default: "draft"
    t.string :payload_digest, null: false
    t.string :provenance_actor_cid
    t.string :provenance_source_cid
    t.datetime :created_at, null: false
  end

  def governed_indexes(table)
    short = table.to_s.sub(/\Aosi_level_8_intent_/, "osi_l8_i_")
    add_index table, :cid, unique: true, name: "idx_#{short}_cid"
    add_index table, [:ledger_placement, :state], name: "idx_#{short}_ledger_state"
    add_check_constraint table, LEDGER_CHECK, name: "chk_#{short}_ledger_placement"
  end
end
