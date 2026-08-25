# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

# RETIRED — Vv::Graph::Loader.normalize_schema! lived on the sqlite-sparql
# Loader, which was removed when Oxigraph became the sole engine.
# Kept as an explicit retirement pin so the suite loads clean.
RSpec.describe "Vv::Graph::Loader.normalize_schema! (retired)" do
  it "Loader surface is gone" do
    expect(defined?(Vv::Graph::Loader)).to be_nil
  end
end
