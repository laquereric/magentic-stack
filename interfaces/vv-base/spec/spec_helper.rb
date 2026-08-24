# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-base"
require "active_record"

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.expect_with(:rspec) { |e| e.syntax = :expect }

  c.before(:suite) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Migration.verbose = false
    path = File.expand_path("../db/migrate/20260824120000_create_vv_base_canonical_homes.rb", __dir__)
    require path
    CreateVvBaseCanonicalHomes.new.change
  end
end
