# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

ENV["LANG"] ||= "en_US.UTF-8"
ENV["LC_ALL"] ||= "en_US.UTF-8"

require "rspec"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "mmg/medallion"

RSpec.configure do |c|
  c.expect_with(:rspec) { |e| e.syntax = :expect }
end
