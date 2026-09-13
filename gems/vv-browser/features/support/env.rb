# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1
#
# Cucumber World mixes Procedures. Steps call the same methods RSpec unit-tests.

gem_lib = File.expand_path("../../lib", __dir__)
$LOAD_PATH.unshift(gem_lib) unless $LOAD_PATH.include?(gem_lib)

require "rspec/expectations"
require "fileutils"
require "tmpdir"
require "vv/browser"
require "vv/browser/cucumber/world"

World(Vv::Browser::CucumberWorld)
World(RSpec::Matchers)

Before("@live") do
  url = board_url!
  unless procedures.reachable?(url)
    skip_this_scenario("board not reachable at #{url}")
  end
end

After do
  close_probe!
  FileUtils.rm_rf(File.dirname(fixture_path)) if fixture_path && File.directory?(File.dirname(fixture_path))
end
