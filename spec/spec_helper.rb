# frozen_string_literal: true
require "mmg-effect-plane"

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.expect_with(:rspec) { |e| e.syntax = :expect }
end
require_relative "support"
