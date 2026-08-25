# frozen_string_literal: true

# P9.6 — SQLite BEFORE UPDATE/DELETE triggers. Same pattern as P5 / M3–M8 / P10.
class AddOsiL8UxAppendOnlyTriggers < ActiveRecord::Migration[8.0]
  TABLES = %w[
    osi_l8_ux_actors
    osi_l8_ux_journeys
    osi_l8_ux_flows
    osi_l8_ux_pages
    osi_l8_ux_acia_documents
    osi_l8_ux_token_sets
    osi_l8_ux_interaction_events
    osi_l8_ux_receipts
    osi_l8_ux_evidences
    osi_l8_ux_activations
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
