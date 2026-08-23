# frozen_string_literal: true

require "mmg/semantic_editor"
require_relative "support/fixtures"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
end
