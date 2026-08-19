require "spec_helper"
require "json"

RSpec.describe "CPCP boundary (BACK /_cpcp seam)" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    JSON.parse(last_response.body)
  end

  it "exposes liveness + declared operations at /_cpcp/up" do
    get "/_cpcp/up"
    expect(last_response.status).to eq(200)
    j = JSON.parse(last_response.body)
    expect(j["ok"]).to be(true)
    expect(j["operations"]).to include("note.create", "note.list", "reconciliation.latest")
  end

  it "PUSH note.create then PULL note.list (sole-writer seam)" do
    before = Note.count
    r = rpc("note.create", { "title" => "via seam", "body" => "hello" }, opid: "op-#{before}")
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "title")).to eq("via seam")
    list = rpc("note.list")
    expect(list["ok"]).to be(true)
    titles = list.dig("result", "@graph").map { |n| n["title"] }
    expect(titles).to include("via seam")
    expect(Note.count).to eq(before + 1)
  end

  it "PUSH without operationId is refused (never-raise envelope)" do
    r = rpc("note.create", { "title" => "x", "body" => "y" })
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("operation_id_required")
  end

  it "unknown operation fails cleanly" do
    r = rpc("does.not.exist")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("unknown_operation")
  end
end
