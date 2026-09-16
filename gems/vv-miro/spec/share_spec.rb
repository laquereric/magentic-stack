# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Miro::Share do
  def ok(data = {})
    { ok: true, data: data }
  end

  def client_with(&handler)
    transport = Vv::Miro::FakeTransport.new(&handler)
    Vv::Miro::Client.new(access_token: "at", transport: transport)
  end

  it "refuses a missing client" do
    r = described_class.push(nil, name: "N", effects: [{ op: "create", item: { type: "shape" } }])
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:client_required)
  end

  it "refuses a blank name" do
    r = described_class.push(client_with { |_| ok }, name: "  ", effects: [{ op: "create" }])
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:name_required)
  end

  it "refuses empty effects" do
    r = described_class.push(client_with { |_| ok }, name: "Workshop", effects: [])
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:effects_required)
  end

  it "creates a board, applies shapes, then connectors, and returns a view link" do
    calls = []
    c = client_with do |call|
      calls << call
      case call[:path]
      when "/v2/boards"
        ok("id" => "b1", "viewLink" => "https://miro.com/app/board/b1/")
      when "/v2/boards/b1/shapes"
        n = calls.count { |x| x[:path] == "/v2/boards/b1/shapes" }
        ok("id" => "s#{n}")
      when "/v2/boards/b1/connectors"
        ok("id" => "c1")
      else
        ok("id" => "x")
      end
    end

    r = described_class.push(c, name: "Workshop", effects: [
      { op: "create", item: { type: "shape", id: "a", shape: "circle", x: -40, y: 0 } },
      { op: "create", item: { type: "shape", id: "b", shape: "circle", x: 40, y: 0 } },
      { op: "create", item: { type: "connector", start: { id: "a" }, end: { id: "b" } } }
    ])

    expect(r[:ok]).to be true
    expect(r[:data]["board_id"]).to eq("b1")
    expect(r[:data]["view_link"]).to eq("https://miro.com/app/board/b1/")
    expect(calls[0][:path]).to eq("/v2/boards")
    expect(calls[0][:body]).to include("name" => "Workshop")
    shape_bodies = calls.select { |x| x[:path] == "/v2/boards/b1/shapes" }.map { |x| x[:body] }
    expect(shape_bodies.size).to eq(2)
    expect(shape_bodies[0]["data"]).not_to have_key("id")
    connector = calls.find { |x| x[:path] == "/v2/boards/b1/connectors" }
    expect(connector[:body][:start] || connector[:body]["start"]).to include("id" => "s1")
    expect(connector[:body][:end] || connector[:body]["end"]).to include("id" => "s2")
  end

  it "falls back to a board URL when REST omits viewLink" do
    c = client_with do |call|
      if call[:path] == "/v2/boards"
        ok("id" => "b9")
      else
        ok("id" => "s1")
      end
    end
    r = described_class.push(c, name: "N", effects: [
      { op: "create", item: { type: "shape", shape: "rectangle" } }
    ])
    expect(r[:ok]).to be true
    expect(r[:data]["view_link"]).to eq("https://miro.com/app/board/b9/")
  end

  it "refuses a connector whose start id was not created" do
    c = client_with do |call|
      call[:path] == "/v2/boards" ? ok("id" => "b1") : ok("id" => "s1")
    end
    r = described_class.push(c, name: "N", effects: [
      { op: "create", item: { type: "shape", id: "a", shape: "circle" } },
      { op: "create", item: { type: "connector", start: { id: "missing" }, end: { id: "a" } } }
    ])
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:connector_unresolved)
  end

  it "is reachable as Client#share" do
    c = client_with do |call|
      call[:path] == "/v2/boards" ? ok("id" => "b1", "viewLink" => "https://miro.com/app/board/b1/") : ok("id" => "s1")
    end
    r = c.share(name: "N", effects: [{ op: "create", item: { type: "shape", shape: "circle" } }])
    expect(r[:ok]).to be true
    expect(r[:data]["board_id"]).to eq("b1")
  end
end
