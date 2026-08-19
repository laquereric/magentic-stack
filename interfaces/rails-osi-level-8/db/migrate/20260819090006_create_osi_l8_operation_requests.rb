# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8OperationRequests < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_operation_requests do |t|
      governed_columns(t)
      t.string :operation_name,       null: false
      t.string :direction,            null: false
      t.string :idempotency_scope,    null: false
      t.string :idempotency_key,      null: false
      t.string :request_context_cid,  null: false
      t.string :effect_cid
      t.string :request_digest,       null: false
      t.string :caller_iri
      t.string :admission_status,     null: false
    end
    governed_indexes(:osi_l8_operation_requests)
    add_index :osi_l8_operation_requests, [:operation_name, :idempotency_scope, :idempotency_key],
              unique: true, name: "idx_osi_l8_op_req_idempotency"
    add_index :osi_l8_operation_requests, :effect_cid
    add_index :osi_l8_operation_requests, :request_context_cid
  end
end
