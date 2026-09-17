# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma::Keys do
  it "keeps snake_case on the wire" do
    out = described_class.to_wire({ file_key: "Ab", node_id: "1:2" })
    expect(out).to include("file_key" => "Ab", "node_id" => "1:2")
  end

  it "drops nils" do
    expect(described_class.compact(a: 1, b: nil)).to eq(a: 1)
  end
end
