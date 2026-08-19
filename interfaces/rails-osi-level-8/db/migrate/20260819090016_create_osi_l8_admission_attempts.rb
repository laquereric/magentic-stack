# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8AdmissionAttempts < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_admission_attempts do |t|
      governed_columns(t)
      t.string  :operation_name,  null: false
      t.string  :direction,       null: false
      t.string  :request_cid
      t.string  :request_digest,  null: false
      t.string  :caller_iri
      t.boolean :conforms,        null: false
      t.string  :refusal_reason
      t.string  :shape_id
      t.string  :shape_digest
      t.json    :report_json,     null: false, default: {}
    end
    governed_indexes(:osi_l8_admission_attempts)
    add_index :osi_l8_admission_attempts, [:operation_name, :recorded_at], name: "idx_osi_l8_admission_op_time"
    add_index :osi_l8_admission_attempts, :request_cid
    add_index :osi_l8_admission_attempts, :conforms
  end
end
