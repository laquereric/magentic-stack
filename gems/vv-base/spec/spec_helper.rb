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

    sessions = File.expand_path("../db/migrate/20260828000002_create_vv_base_sessions.rb", __dir__)
    require sessions
    CreateVvBaseSessions.new.change

    steps = File.expand_path("../db/migrate/20260912000000_create_vv_base_flow_steps_and_information_models.rb", __dir__)
    require steps
    CreateVvBaseFlowStepsAndInformationModels.new.change
  end

  c.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
