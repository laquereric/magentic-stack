# frozen_string_literal: true

require "spec_helper"

RSpec.describe "intent → ux lineage (F1/F3/J1)" do
  include Rack::Test::Methods
  def app = Rails.application

  def g = RailsOsiLevel8::Profile9::Graph

  def rpc(method, params = {})
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    JSON.parse(last_response.body)
  end

  before { g.reset! }

  it "J1 is a vv-base Journey whose projection CID is the P9 envelope cid" do
    expect(g.vv_base_ready?).to eq(true)
    journey = Vv::Base::Journey.find_by!(title: RailsOsiLevel8::Profile9::J1::JOURNEY_TITLE)
    expected = RailsOsiLevel8::Intent::Projection.for(journey)["cid"]
    expect(g.j1_journey_cid).to eq(expected)
    expect(g.j1_journey_cid).to start_with("cid:sha256:")
    expect(g.j1_journey_cid).not_to eq(RailsOsiLevel8::Profile9::Graph::JOURNEY_CID)
  end

  it "ux.journey.get returns the same intentGroundingCid as Grounding.for_journey" do
    journey = Vv::Base::Journey.find_by!(title: RailsOsiLevel8::Profile9::J1::JOURNEY_TITLE)
    bound = RailsOsiLevel8::Intent::Grounding.for_journey(journey)
    expect(bound).not_to be_empty
    env = rpc("ux.journey.get", { "journeyCid" => g.j1_journey_cid })
    expect(env["ok"]).to eq(true)
    expect(env.dig("result", "intentGroundingCid")).to eq(bound.first["cid"])
    expect(env.dig("result", "cid")).to eq(g.j1_journey_cid)
  end

  it "refuses a P9 journey CID that is not the vv-base projection" do
    real = g.journey(g.j1_journey_cid)
    g.journeys["cid:journey:rogue"] = real.merge("cid" => "cid:journey:rogue")
    env = rpc("ux.journey.get", { "journeyCid" => "cid:journey:rogue" })
    expect(env["ok"]).to eq(false)
    expect(env.dig("error", "reason")).to eq("UX_LINEAGE_UNRESOLVED")
    expect(env.dig("error", "because", "resource")).to eq("projection")
  end

  it "ux.page.get carries flow/step/acia/grounding cites on J1" do
    env = rpc("ux.page.get", {
      "pageCid" => g.j1_page_cid,
      "correlationId" => "corr-j1",
      "receiptSeed" => "seed-j1"
    })
    expect(env["ok"]).to eq(true)
    page = env.dig("result", "page")
    expect(page["flowCid"]).to eq(g.j1_flow_cid)
    expect(page["stepKey"]).to eq(g.j1_step_key)
    expect(page["aciaCid"]).to be_present
    expect(page["intentGroundingCid"]).to eq(g.j1_grounding_cid)
  end
end
