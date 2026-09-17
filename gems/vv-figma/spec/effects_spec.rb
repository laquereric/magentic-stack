# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma::Effects do
  it "maps create comment onto REST" do
    r = described_class.to_rest(
      { op: "create", item: { type: "comment", message: "hello", x: 1, y: 2 } },
      file_key: "Ab"
    )
    expect(r[:ok]).to be true
    expect(r[:data][:method]).to eq(:post)
    expect(r[:data][:path]).to eq("/v1/files/Ab/comments")
    expect(r[:data][:body][:message]).to eq("hello")
    expect(r[:data][:body][:client_meta]).to include(x: 1, y: 2)
  end

  it "refuses creating a rectangle on REST" do
    r = described_class.to_rest(
      { op: "create", item: { type: "rectangle", width: 10 } },
      file_key: "Ab"
    )
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:plugin_required)
  end

  it "refuses broadcast on REST" do
    r = described_class.to_rest({ op: "broadcast", event: "vv-figma" }, file_key: "Ab")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:broadcast_rest_unsupported)
  end

  it "refuses an unknown item type" do
    r = described_class.to_rest({ op: "create", item: { type: "kanban" } }, file_key: "Ab")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:item_type_unsupported)
  end

  it "maps comment delete onto REST" do
    r = described_class.to_rest(
      { op: "delete", item: { type: "comment", id: "c1" } },
      file_key: "Ab"
    )
    expect(r[:ok]).to be true
    expect(r[:data][:method]).to eq(:delete)
    expect(r[:data][:path]).to eq("/v1/files/Ab/comments/c1")
  end
end
