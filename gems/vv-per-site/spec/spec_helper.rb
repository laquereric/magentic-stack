# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-per-site"
require "active_record"

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.expect_with(:rspec) { |e| e.syntax = :expect }
  c.order = :random

  c.before(:suite) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Migration.verbose = false
    result = Vv::PerSite::Migrator.run!
    raise result[:because] unless result[:ok]
  end

  c.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end

def fixture_docs
  File.expand_path("fixtures/docs", __dir__)
end

def sic_docs
  File.expand_path("../../stewardship-intelligence-cloud/docs", __dir__)
end
