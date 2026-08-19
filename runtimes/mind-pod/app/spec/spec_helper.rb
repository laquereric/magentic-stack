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

RSpec.configure do |c|
  c.expect_with(:rspec) { |e| e.syntax = :expect }
  c.around(:each) do |example|
    ActiveRecord::Base.connection.begin_transaction(joinable: false)
    example.run
  ensure
    ActiveRecord::Base.connection.rollback_transaction
  end
end
