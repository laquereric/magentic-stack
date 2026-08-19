# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8RoutingDecisions < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_routing_decisions do |t|
      governed_columns(t)
      t.string :route_key,              null: false
      t.string :operation_request_cid,  null: false
      t.string :effect_cid
      t.string :chosen_target_iri,      null: false
      t.string :chosen_channel_cid
      t.string :policy_ref
      t.string :decision,               null: false
      t.string :reason_code,            null: false
      t.string :candidate_digest
    end
    governed_indexes(:osi_l8_routing_decisions)
    add_index :osi_l8_routing_decisions, [:operation_request_cid, :recorded_at],
              name: "idx_osi_l8_route_dec_op_time"
    add_index :osi_l8_routing_decisions, :route_key
    add_index :osi_l8_routing_decisions, :chosen_target_iri
  end
end
