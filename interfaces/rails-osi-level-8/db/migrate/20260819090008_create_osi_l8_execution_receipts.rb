# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8ExecutionReceipts < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_execution_receipts do |t|
      governed_columns(t)
      t.string   :operation_request_cid,       null: false
      t.string   :effect_cid
      t.string   :execution_key,               null: false
      t.string   :status,                      null: false
      t.string   :result_context_cid
      t.string   :result_digest
      t.datetime :completed_at,                null: false
      t.string   :failure_reason
      t.string   :replayed_from_receipt_cid
    end
    governed_indexes(:osi_l8_execution_receipts)
    add_index :osi_l8_execution_receipts, :operation_request_cid, unique: true
    add_index :osi_l8_execution_receipts, :execution_key, unique: true
    add_index :osi_l8_execution_receipts, :effect_cid
    add_index :osi_l8_execution_receipts, :completed_at
  end
end
