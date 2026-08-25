# frozen_string_literal: true
require "tmpdir"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../vv-blob/lib", __dir__)
require "mmg-blob"
RSpec.configure { |c| c.disable_monkey_patching!; c.order = :random }
