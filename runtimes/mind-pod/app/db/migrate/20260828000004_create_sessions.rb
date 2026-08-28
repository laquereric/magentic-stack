# frozen_string_literal: true

# The cyborg session table (Vv::Base::Session).
#
# The pod carries its own migrations for the vv-base homes -- see
# 20260819180001_create_canonical_intent_homes.rb, which creates actors/journeys
# the same way -- rather than installing the gem's. Kept in step with
# gems/vv-base/db/migrate/20260828000002_create_vv_base_sessions.rb.
#
# actor_id is nullable and unconstrained: the pod has no authentication, so an
# actor may be asserted, unknown or absent. Forcing one would mean inventing one.
class CreateSessions < ActiveRecord::Migration[8.1]
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
