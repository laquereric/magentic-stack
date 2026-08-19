# frozen_string_literal: true

# Additive triggers for Profile 5 tables. Migration 17 already ran on M0/M1 DBs;
# this covers biography_events + provenance_edges without rewriting history.
class AddOsiL8P5AppendOnlyTriggers < ActiveRecord::Migration[8.0]
  TABLES = %w[
    osi_l8_biography_events
    osi_l8_provenance_edges
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
