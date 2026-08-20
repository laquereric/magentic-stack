ENV["RAILS_ENV"] ||= "test"
ENV["DB_PATH"] ||= "db/test.sqlite3"
ENV["ROLE"] ||= "back"
require_relative "../config/environment"
require "rack/test"
require "securerandom"
require "digest"

# Engine migrations are appended at boot; `db:migrate` can no-op on a fresh test DB
# in this slim app, so ensure schema.rb is applied before examples run.
unless ActiveRecord::Base.connection.data_source_exists?("notes")
  load(Rails.root.join("db/schema.rb"))
end

def osi_l8_table?(name)
  ActiveRecord::Base.connection.data_source_exists?(name)
end

unless osi_l8_table?("osi_l8_ux_journeys") &&
       osi_l8_table?("osi_l8_mng_concepts") &&
       osi_l8_table?("osi_l8_mng_semantic_disputes") &&
       osi_l8_table?("osi_l8_mng_stewardship_translations")
  engine_migrate = Rails.root.join("vendor/rails-osi-level-8/db/migrate").to_s
  app_migrate = Rails.root.join("db/migrate").to_s
  pool = ActiveRecord::Base.connection_pool
  ActiveRecord::MigrationContext.new(
    [app_migrate, engine_migrate],
    pool.schema_migration,
    pool.internal_metadata
  ).migrate
end

RSpec.configure do |c|
  c.expect_with(:rspec) { |e| e.syntax = :expect }
  c.around(:each) do |example|
    ActiveRecord::Base.connection.begin_transaction(joinable: false)
    example.run
  ensure
    ActiveRecord::Base.connection.rollback_transaction
  end
end
