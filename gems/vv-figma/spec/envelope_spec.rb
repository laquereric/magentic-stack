# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma::Envelope do
  it "wraps a file document as ok data" do
    r = described_class.from_figma({ "name" => "Care", "document" => { "id" => "0:1" } })
    expect(r[:ok]).to be true
    expect(r[:data]["name"]).to eq("Care")
  end

  it "maps a Figma err body" do
    r = described_class.from_figma({ "status" => 403, "err" => "Invalid token" }, http_status: 403)
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:figma_error)
    expect(r[:because]).to eq("Invalid token")
  end
end
