# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "P11 Meaning CPCP" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    JSON.parse(last_response.body)
  end

  before { RailsOsiLevel8::Profile11::Store.reset! }

  it "meaning.profile.describe is on the wire" do
    r = rpc("meaning.profile.describe")
    expect(last_response.status).to eq(200)
    expect(r["ok"]).to be(true)
    expect(r["jsonrpc"]).to eq("2.0")
    expect(r.dig("result", "profile_id")).to eq("osi-level-8/profile-11")
  end

  it "P11.3 seed persists append-only; evaluate via /_cpcp" do
    c = rpc("meaning.concept.put", {
      "cid" => "https://ex/concept/alpha", "@type" => "Concept",
      "label" => "Alpha", "scope" => "https://ex/scope/pod"
    }, opid: "p11-c-#{SecureRandom.hex(3)}")
    expect(c["ok"]).to be(true)
    expect(RailsOsiLevel8::MngConcept.find_by(cid: "https://ex/concept/alpha")).to be_present

    rev = rpc("meaning.revision.put", {
      "cid" => "https://ex/rev/alpha/1", "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha", "content" => "Alpha",
      "scope" => "https://ex/scope/pod", "definitionLifecycle" => "candidate",
      "formalization" => "structured"
    }, opid: "p11-r-#{SecureRandom.hex(3)}")
    expect(rev["ok"]).to be(true)

    ev = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "scope" => "https://ex/scope/pod",
      "namedUse" => "explore"
    }, opid: "p11-e-#{SecureRandom.hex(3)}")
    expect(ev["ok"]).to be(true)
    expect(ev.dig("result", "actabilityBand")).to eq("explorable")

    disp = rpc("meaning.dispute.put", {
      "cid" => "https://ex/disp/1", "@type" => "SemanticDispute",
      "target" => "https://ex/rev/alpha/1",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "concept" => "https://ex/concept/alpha",
      "scope" => "https://ex/scope/pod",
      "raiser" => "https://ex/actor/challenger",
      "claim" => "contested",
      "evidenceRef" => "https://ex/p5/1"
    }, opid: "p11-d-#{SecureRandom.hex(3)}")
    expect(disp["ok"]).to be(true)
    expect(RailsOsiLevel8::MngSemanticDispute.find_by(cid: "https://ex/disp/1")).to be_present

    extra = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "style" => "nope"
    }, opid: "p11-bad-#{SecureRandom.hex(3)}")
    expect(extra["ok"]).to be(false)
    expect(extra.dig("error", "reason")).to eq("meaning.policy-indeterminate")

    expect {
      ActiveRecord::Base.connection.execute(
        "UPDATE osi_l8_mng_concepts SET payload_digest='tamper' WHERE cid='https://ex/concept/alpha'"
      )
    }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
