# frozen_string_literal: true

# The cyborg session: one row per user session, human or agent.
#
# actor_id is NULLABLE and has no FK constraint to actors: the pod has no
# authentication, so an actor may be asserted, unknown, or absent. A NOT NULL here
# would force callers to invent an actor, and an invented actor reads as evidence.
class CreateVvBaseSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :sessions do |t|
      t.bigint   :actor_id
      t.string   :actor_kind, null: false
      t.string   :state,      null: false, default: "open"
      t.integer  :generation, null: false, default: 0
      t.datetime :opened_at,  null: false
      t.datetime :closed_at
      t.string   :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :sessions, :actor_id
    add_index :sessions, :state
    add_index :sessions, :actor_kind
  end
end
