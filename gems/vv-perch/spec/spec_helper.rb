# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-perch"
require "active_record"

module Vv
  module Base
    class Actor < ActiveRecord::Base
      self.table_name = "actors"
    end
  end
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.expect_with(:rspec) { |e| e.syntax = :expect }

  c.before(:suite) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      create_table :actors do |t|
        t.string :name, null: false
        t.string :role_key, null: false
        t.timestamps
      end
      add_index :actors, :role_key, unique: true
    end
    Dir[File.expand_path("../db/migrate/*.rb", __dir__)].sort.each do |path|
      require path
      name = File.basename(path)[/\A\d+_(.+)\.rb\z/, 1]
      Object.const_get(name.split("_").map(&:capitalize).join).new.change
    end
  end

  c.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
