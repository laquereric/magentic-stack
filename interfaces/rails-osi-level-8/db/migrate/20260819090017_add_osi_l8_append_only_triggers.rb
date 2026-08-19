# frozen_string_literal: true

class AddOsiL8AppendOnlyTriggers < ActiveRecord::Migration[8.0]
  TABLES = %w[
    osi_l8_contexts
    osi_l8_cyborg_channels
    osi_l8_operation_requests
    osi_l8_operation_journal_entries
    osi_l8_execution_receipts
    osi_l8_admission_attempts
  ].freeze

  def up
    TABLES.each do |table|
      execute <<~SQL
        CREATE TRIGGER IF NOT EXISTS #{table}_no_update
        BEFORE UPDATE ON #{table}
        BEGIN
          SELECT RAISE(ABORT, 'osi_l8 append-only: UPDATE forbidden on #{table}');
        END;
      SQL
      execute <<~SQL
        CREATE TRIGGER IF NOT EXISTS #{table}_no_delete
        BEFORE DELETE ON #{table}
        BEGIN
          SELECT RAISE(ABORT, 'osi_l8 append-only: DELETE forbidden on #{table}');
        END;
      SQL
    end
  end

  def down
    TABLES.each do |table|
      execute "DROP TRIGGER IF EXISTS #{table}_no_update;"
      execute "DROP TRIGGER IF EXISTS #{table}_no_delete;"
    end
  end
end
