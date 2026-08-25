# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8RoutingHops < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_routing_hops do |t|
      governed_columns(t)
      t.string   :routing_decision_cid, null: false
      t.integer  :hop_number,           null: false
      t.string   :from_iri,             null: false
      t.string   :to_iri,               null: false
      t.string   :channel_cid
      t.string   :hop_status,           null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.string   :failure_code
    end
    governed_indexes(:osi_l8_routing_hops)
    add_index :osi_l8_routing_hops, [:routing_decision_cid, :hop_number],
              unique: true, name: "idx_osi_l8_route_hop_dec_num"
    add_index :osi_l8_routing_hops, :channel_cid
    add_index :osi_l8_routing_hops, :to_iri
  end
end
