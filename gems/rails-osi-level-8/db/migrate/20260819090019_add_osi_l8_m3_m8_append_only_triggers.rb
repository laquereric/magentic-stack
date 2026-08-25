# frozen_string_literal: true

# Additive triggers for Milestone 3–8 tables. Migration 17 already ran on
# earlier DBs; this covers the new profile tables without rewriting history.
class AddOsiL8M3M8AppendOnlyTriggers < ActiveRecord::Migration[8.0]
  TABLES = %w[
    osi_l8_reference_passes
    osi_l8_routing_decisions
    osi_l8_routing_hops
    osi_l8_authorization_evidences
    osi_l8_observations
    osi_l8_outcomes
    osi_l8_learning_events
    osi_l8_profile_evidences
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
