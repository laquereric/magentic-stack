# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

RSpec.describe Vv::Graph do
  it "ships a VERSION constant" do
    expect(Vv::Graph::VERSION).to be_a(String).and(be_present)
  end

  it "is at v0.x.x (substrate-mutual evolution; v1.0 is the publication milestone)" do
    expect(Vv::Graph::VERSION).to start_with("0.")
  end
end
