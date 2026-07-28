# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv; end

module Vv::Graph
  # Single source of truth for the gem version is the root VERSION
  # file, matching the substrate's repo-root convention
  # (agent-os/rules/ruby.md). The gemspec consumes
  # Vv::Graph::VERSION; bumps go in the VERSION file, not here.
  VERSION = File.read(File.expand_path("../../../VERSION", __dir__)).strip
end
