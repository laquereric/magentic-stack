# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Miro::Effects do
  it "maps create app_card onto REST v2" do
    r = described_class.to_rest(
      { op: "create", item: { type: "app_card", title: "call", status: "disconnected", x: 10, y: 20 } },
      board_id: "board-1"
    )
    expect(r[:ok]).to be true
    expect(r[:data][:method]).to eq(:post)
    expect(r[:data][:path]).to eq("/v2/boards/board-1/app_cards")
    expect(r[:data][:body][:data]).to include(title: "call", status: "disconnected")
    expect(r[:data][:body][:position]).to include(x: 10, y: 20)
  end

  it "maps delete onto /items/:id" do
    r = described_class.to_rest(
      { op: "delete", item: { type: "sticky_note", id: "i1" } },
      board_id: "board-1"
    )
    expect(r[:ok]).to be true
    expect(r[:data][:method]).to eq(:delete)
    expect(r[:data][:path]).to eq("/v2/boards/board-1/items/i1")
  end

  it "refuses broadcast on REST" do
    r = described_class.to_rest({ op: "broadcast", event: "vv-miro" }, board_id: "board-1")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:broadcast_rest_unsupported)
  end

  it "refuses an unknown item type" do
    r = described_class.to_rest({ op: "create", item: { type: "kanban" } }, board_id: "board-1")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:item_type_unsupported)
  end

  it "refuses update without an item id" do
    r = described_class.to_rest({ op: "update", item: { type: "shape" } }, board_id: "board-1")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:item_id_required)
  end
end
