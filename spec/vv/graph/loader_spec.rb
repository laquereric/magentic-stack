# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

# RETIRED — Vv::Graph::Loader (sqlite-sparql native extension) was removed.
# Oxigraph SPARQL-over-HTTP (Vv::Graph::OxirsBackend) is the sole engine.
# Kept as an explicit skip so the suite loads clean (S2 harness bounce fix).
RSpec.describe "Vv::Graph::Loader (retired)" do
  it "is no longer part of the gem surface" do
    expect(defined?(Vv::Graph::Loader)).to be_nil
  end
end
