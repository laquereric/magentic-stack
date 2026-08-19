# frozen_string_literal: true

require "rspec"
require_relative "../lib/rails-osi-level-8"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
