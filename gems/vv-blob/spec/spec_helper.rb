# frozen_string_literal: true
require "tmpdir"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-blob"

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.order = :random
end
