# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1
#
# Standalone ACIA core specs — pure Tree + Markdown (no Rails engine, no AR).
# Load path is relative so `rspec` from the gem root works without Bundler.

require "rspec"

GEM_LIB = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(GEM_LIB) unless $LOAD_PATH.include?(GEM_LIB)

require "mmg/acia/tree"
require "mmg/acia/markdown"
require "mmg/acia/state"
require "mmg/acia/transition"
require "mmg/acia/validated_snapshot"
require "mmg/acia/tab_tree"
require "mmg/acia"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
