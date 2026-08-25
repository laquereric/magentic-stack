# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8OperationJournalEntries < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_operation_journal_entries do |t|
      governed_columns(t)
      t.string   :operation_request_cid, null: false
      t.integer  :sequence,              null: false
      t.string   :event_kind,            null: false
      t.datetime :event_at,              null: false
      t.json     :detail_json,           null: false, default: {}
      t.string   :receipt_cid
    end
    governed_indexes(:osi_l8_operation_journal_entries)
    add_index :osi_l8_operation_journal_entries, [:operation_request_cid, :sequence],
              unique: true, name: "idx_osi_l8_journal_req_seq"
    add_index :osi_l8_operation_journal_entries, [:operation_request_cid, :event_at],
              name: "idx_osi_l8_journal_req_time"
    add_index :osi_l8_operation_journal_entries, :event_kind
  end
end
