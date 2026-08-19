# frozen_string_literal: true

# P10.M2 — SQLite BEFORE UPDATE/DELETE triggers for Profile 10 intent tables.
class AddOsiL8IntentAppendOnlyTriggers < ActiveRecord::Migration[8.0]
  TABLES = %w[
    osi_level_8_intent_stakeholders
    osi_level_8_intent_value_propositions
    osi_level_8_intent_offers
    osi_level_8_intent_market_segments
    osi_level_8_intent_economic_actors
    osi_level_8_intent_exchange_relationships
    osi_level_8_intent_goals
    osi_level_8_intent_key_results
    osi_level_8_intent_outcomes
    osi_level_8_intent_value_metrics
    osi_level_8_intent_constraints
    osi_level_8_intent_externalities
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
