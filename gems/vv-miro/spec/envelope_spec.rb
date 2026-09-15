# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Miro::Envelope do
  it "wraps success with data:" do
    r = described_class.ok(data: { "id" => "b1" })
    expect(r[:ok]).to be true
    expect(r[:data]).to eq("id" => "b1")
  end

  it "refuses with a symbol reason" do
    r = described_class.refuse(:board_required, "needs a board")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:board_required)
    expect(r[:because]).to eq("needs a board")
  end

  it "unwraps a Miro list payload and keeps the cursor" do
    r = described_class.from_miro({ "data" => [{ "id" => "1" }], "cursor" => "abc" }, http_status: 200)
    expect(r[:ok]).to be true
    expect(r[:data]).to eq([{ "id" => "1" }])
    expect(r[:cursor]).to eq("abc")
  end

  it "maps a Miro error object" do
    r = described_class.from_miro(
      { "type" => "error", "code" => "invalidParameters", "message" => "bad", "status" => 400 },
      http_status: 400
    )
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:miro_error)
    expect(r[:because]).to eq("bad")
    expect(r[:code]).to eq("invalidParameters")
  end
end
