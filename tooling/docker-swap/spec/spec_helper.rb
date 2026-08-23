# frozen_string_literal: true
require "vv-docker-swap"

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.expect_with(:rspec) { |e| e.syntax = :expect }
end
