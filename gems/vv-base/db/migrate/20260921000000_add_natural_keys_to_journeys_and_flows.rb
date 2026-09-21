# frozen_string_literal: true

# ADR 0074 decision 1. A canonical home row is identified by a natural key.
#
# Journeys and flows had none. The indexes on journeys were status,
# primary_actor_id and ledger_placement; on flows, journey_id, status and
# ledger_placement. Nothing unique, which is why two callers could seed the
# same table with two different idempotence keys and neither be wrong:
# j1.rb:41 keys on (title, primary_actor_id), mind-pod's db/seeds.rb:22 on
# title alone. The result depended on run order.
#
# flow_steps already had this discipline at (flow_id, step_key). This extends
# it upward to the parents rather than introducing a new idea.
#
# The keys arrive NULLABLE, are backfilled from title, and only then become
# NOT NULL. Adding them NOT NULL with a default would put a default in a
# column whose entire purpose is to refuse defaulting -- the mistake ADR 0074's
# own Context is about, one table over.
class AddNaturalKeysToJourneysAndFlows < ActiveRecord::Migration[7.0]
  def change
    add_column :journeys, :journey_key, :string
    add_column :flows, :flow_key, :string

    reversible do |dir|
      dir.up { backfill_keys }
    end

    change_column_null :journeys, :journey_key, false
    change_column_null :flows, :flow_key, false

    # Global here, and deliberately provisional: decision 2 adds bundle_key to
    # journeys and replaces this with (bundle_key, journey_key). Until that
    # lands there is one bundle, so a global key is correct and this migration
    # stands alone -- which ADR 0074 asks of each move.
    add_index :journeys, :journey_key, unique: true
    add_index :flows, %i[journey_id flow_key], unique: true, name: "idx_flows_journey_key"
  end

  private

  # Derived from title, because that is the only thing the existing rows carry
  # that a human chose. Collisions take an id suffix rather than failing the
  # migration: a duplicate title is not a reason to refuse to start, and the
  # suffixed key is still stable for that row.
  def backfill_keys
    assign(:journeys, :journey_key, scope_column: nil)
    assign(:flows, :flow_key, scope_column: :journey_id)
  end

  def assign(table, key_column, scope_column:)
    cols = ["id", "title"]
    cols << scope_column.to_s if scope_column
    rows = select_all("SELECT #{cols.join(', ')} FROM #{table} WHERE #{key_column} IS NULL OR #{key_column} = ''").to_a
    return if rows.empty?

    taken = Hash.new { |h, k| h[k] = {} }
    select_all("SELECT #{(cols - ['title']).join(', ')}, #{key_column} FROM #{table} WHERE #{key_column} IS NOT NULL AND #{key_column} != ''")
      .to_a.each do |r|
        bucket = scope_column ? r[scope_column.to_s] : nil
        taken[bucket][r[key_column.to_s]] = true
      end

    rows.each do |row|
      bucket = scope_column ? row[scope_column.to_s] : nil
      base = slug(row["title"])
      key = base
      key = "#{base}-#{row['id']}" if taken[bucket].key?(key)
      taken[bucket][key] = true
      execute("UPDATE #{table} SET #{key_column} = #{quote(key)} WHERE id = #{row['id'].to_i}")
    end
  end

  def slug(title)
    s = title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    s.empty? ? "untitled" : s
  end
end
