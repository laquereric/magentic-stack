# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Miro::Client do
  def ok(data = {})
    { ok: true, data: data }
  end

  def client_with(&handler)
    transport = Vv::Miro::FakeTransport.new(&handler)
    described_class.new(access_token: "at", transport: transport)
  end

  describe "refusals before the wire" do
    it "refuses a missing board id" do
      r = client_with { |_| ok }.get_board("")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:board_required)
    end

    it "refuses a missing item id" do
      r = client_with { |_| ok }.delete_item("b1", nil)
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:item_id_required)
    end

    it "refuses an unknown item type" do
      r = client_with { |_| ok }.create_item("b1", type: "kanban")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:item_type_unsupported)
    end
  end

  describe "boards" do
    it "lists boards on GET /v2/boards" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok([{ "id" => "b1" }])
      end
      r = c.list_boards(team_id: "t1", limit: 10)
      expect(r[:ok]).to be true
      expect(seen[:method]).to eq(:get)
      expect(seen[:path]).to eq("/v2/boards")
      expect(seen[:query]).to include(team_id: "t1", limit: 10)
    end

    it "creates a board" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok("id" => "b1")
      end
      c.create_board(name: "Workshop")
      expect(seen[:method]).to eq(:post)
      expect(seen[:path]).to eq("/v2/boards")
      expect(seen[:body]).to include("name" => "Workshop")
    end
  end

  describe "app cards" do
    it "creates an app card on the typed collection" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok("id" => "c1", "type" => "app_card")
      end
      c.create_app_card("b1", data: { title: "call", status: "disconnected" })
      expect(seen[:method]).to eq(:post)
      expect(seen[:path]).to eq("/v2/boards/b1/app_cards")
      expect(seen[:body]["data"]).to include("title" => "call")
    end
  end

  describe "apply_effect" do
    it "POSTs a create sticky note" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok("id" => "s1")
      end
      r = c.apply_effect("b1", op: "create", item: { type: "sticky_note", content: "hi", x: 0, y: 0 })
      expect(r[:ok]).to be true
      expect(seen[:path]).to eq("/v2/boards/b1/sticky_notes")
      expect(seen[:body]["data"]).to include("content" => "hi")
    end
  end

  describe "webhooks" do
    it "creates a subscription" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok("id" => "wh1")
      end
      c.create_webhook(board_id: "b1", callback_url: "https://example/hook")
      expect(seen[:path]).to eq("/v2/webhooks/subscriptions")
      expect(seen[:body]).to include("boardId" => "b1", "callbackUrl" => "https://example/hook")
    end
  end
end
