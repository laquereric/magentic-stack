ENV["RAILS_ENV"] ||= "test"
ENV["DB_PATH"] ||= "db/test.sqlite3"
ENV["BUS_DB_PATH"] ||= "db/test_bus.sqlite3"
ENV["PERSIST_DB_PATH"] ||= "db/test_persist.sqlite3"
ENV["ROLE"] ||= "back"
require_relative "../config/environment"
require "rack/test"
require "securerandom"
require "digest"

# Engine migrations are appended at boot; `db:migrate` can no-op on a fresh test DB
# in this slim app, so ensure schema.rb is applied before examples run.
unless ApplicationRecord.connection.data_source_exists?("notes")
  load(Rails.root.join("db/schema.rb"))
end

# Transition: test DBs created before the BUS split still carry
# bus_projections in the primary file. The drop migration
# (20260904000001) removes it in deployed volumes; drop it here too so the
# suite proves the split rather than inheriting the old layout.
if ApplicationRecord.connection.data_source_exists?("bus_projections")
  ApplicationRecord.connection.drop_table(:bus_projections)
end

# BUS sqlite (bus-data volume in deploy; separate file here). bus_projections
# lives here now, not in the primary schema. Created directly on the bus
# connection: `MigrationContext#migrate` follows `ActiveRecord::Base`'s
# connection regardless of which pool's schema_migration it is handed, so it
# cannot target the bus DB from here. Production migrates via the official
# `rails db:migrate:bus` task (entrypoint `bus)` branch), which handles the
# per-database connection correctly.
unless BusRecord.connection.data_source_exists?("bus_projections")
  BusRecord.connection.create_table "bus_projections" do |t|
    t.string :source, null: false
    t.text :payload_json, null: false
    t.datetime :projected_at, null: false
    t.timestamps
  end
  BusRecord.connection.add_index "bus_projections", ["projected_at"],
    name: "index_bus_projections_on_projected_at"
end

# PERSIST sqlite (persist-data volume in deploy; separate file here).
# persist_placements lives here, never in the primary schema (ROW8 section 4).
# Same direct-creation reason as the bus table above; production migrates via
# the official `rails db:migrate:persist` task (entrypoint `persist)` branch).
unless PersistRecord.connection.data_source_exists?("persist_placements")
  PersistRecord.connection.create_table "persist_placements" do |t|
    t.string :store, null: false
    t.text :path, null: false
    t.string :set_by, null: false
    t.datetime :recorded_at, null: false
    t.timestamps
  end
  PersistRecord.connection.add_index "persist_placements", ["store"],
    name: "index_persist_placements_on_store", unique: true
end

def osi_l8_table?(name)
  ApplicationRecord.connection.data_source_exists?(name)
end

unless osi_l8_table?("osi_l8_ux_journeys") &&
       osi_l8_table?("osi_l8_mng_concepts") &&
       osi_l8_table?("osi_l8_mng_semantic_disputes") &&
       osi_l8_table?("osi_l8_mng_stewardship_translations") &&
       osi_l8_table?("osi_l8_mng_normative_artifacts") &&
       osi_l8_table?("osi_l8_mng_alignment_assertions") &&
       osi_l8_table?("osi_l8_mng_verification_evidences")
  # Installed gem, not vendored -- Engine.root, not Rails.root.join("vendor/...").
  engine_migrate = RailsOsiLevel8::Engine.root.join("db/migrate").to_s
  app_migrate = Rails.root.join("db/migrate").to_s
  pool = ApplicationRecord.connection_pool
  ActiveRecord::MigrationContext.new(
    [app_migrate, engine_migrate],
    pool.schema_migration,
    pool.internal_metadata
  ).migrate
end

RSpec.configure do |c|
  c.expect_with(:rspec) { |e| e.syntax = :expect }
  c.around(:each) do |example|
    ApplicationRecord.connection.begin_transaction(joinable: false)
    BusRecord.connection.begin_transaction(joinable: false)
    PersistRecord.connection.begin_transaction(joinable: false)
    example.run
  ensure
    PersistRecord.connection.rollback_transaction
    BusRecord.connection.rollback_transaction
    ApplicationRecord.connection.rollback_transaction
  end
end
