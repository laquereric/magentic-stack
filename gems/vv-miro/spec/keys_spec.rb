# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Miro::Keys do
  it "camelizes nested body keys" do
    wire = described_class.to_wire({ fill_color: "#fff", card_theme: "#2d9bf0" })
    expect(wire).to eq("fillColor" => "#fff", "cardTheme" => "#2d9bf0")
  end

  it "keeps query params snake_case" do
    wire = described_class.to_wire({ team_id: "t1", limit: 10 }, query: true)
    expect(wire).to eq("team_id" => "t1", "limit" => 10)
  end

  it "drops nils" do
    expect(described_class.compact(a: 1, b: nil)).to eq(a: 1)
  end
end
