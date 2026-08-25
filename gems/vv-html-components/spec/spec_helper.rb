# frozen_string_literal: true

require "rspec"
require_relative "../lib/vv-html-components"

RSpec.configure do |c|
  c.expect_with :rspec do |e|
    e.syntax = :expect
  end
end
