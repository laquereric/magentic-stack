# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../vv-bpmn-bbo/lib", __dir__)
require "vv-sdlc"
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
    end
    path = File.expand_path("../../vv-bpmn-bbo/db/migrate/20260911000000_create_vv_bpmn_bbo.rb", __dir__)
    require path
    CreateVvBpmnBbo.new.change
  end

  c.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
