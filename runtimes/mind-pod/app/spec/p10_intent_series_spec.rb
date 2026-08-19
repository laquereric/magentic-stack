# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "P10.M2–M7 INTENT series" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    JSON.parse(last_response.body)
  end

  before do
    RailsOsiLevel8::Intent::GraphStore.reset!
  end

  it "M2: creates immutable intent entity rows; forbids updates; no forbidden tables" do
    tables = ActiveRecord::Base.connection.tables
    expect(tables).to include("osi_level_8_intent_stakeholders", "osi_level_8_intent_goals")
    expect(tables.grep(/intent_mission|intent_persona|intent_grounding|intent_trace/)).to be_empty

    st = RailsOsiLevel8::Intent::Factory.create!(
      RailsOsiLevel8::Intent::Stakeholder,
      name: "Community", stakeholder_kind: "community", stake_statement: "Trust"
    )
    expect(st.cid).to start_with("cid:sha256:")
    expect {
      st.update!(name: "Nope")
    }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "M3: validator accepts closed grounding and rejects unknown predicate / missing digest / malformed trace" do
    ok = {
      "@type" => "intent:IntentGrounding",
      "cid" => "cid:g1",
      "profileId" => "osi-level-8/profile-10",
      "ledgerPlacement" => "canonical",
      "digest" => "sha256:#{'a' * 64}",
      "journeyCid" => "cid:j",
      "missionCid" => "cid:m",
      "personaCid" => "cid:p",
      "goalCid" => "cid:g",
      "valuePropositionCid" => "cid:v",
      "validFrom" => Time.now.utc.iso8601,
      "status" => "ratified"
    }
    expect(RailsOsiLevel8::Intent::Validator.validate(ok).conforms?).to be(true)

    bad = ok.merge("arbitraryHtml" => "<b>")
    r = RailsOsiLevel8::Intent::Validator.validate(bad)
    expect(r.conforms?).to be(false)
    expect(r.reason).to eq("unknown_predicate")

    expect(RailsOsiLevel8::Intent::Validator.validate(ok.except("digest")).reason).to eq("missing_digest")

    persona = { "@type" => "intent:Persona", "cid" => "cid:p", "profileId" => "osi-level-8/profile-10",
                "ledgerPlacement" => "canonical", "digest" => "sha256:#{'b' * 64}", "title" => "X",
                "evidenceStatus" => "validated" }
    expect(RailsOsiLevel8::Intent::Validator.validate(persona).reason).to eq("persona_not_backed_by_cohort")

    trace = { "@type" => "intent:IntentTrace", "cid" => "cid:t", "profileId" => "osi-level-8/profile-10",
              "ledgerPlacement" => "canonical", "digest" => "sha256:#{'c' * 64}",
              "effectCid" => "cid:e", "groundingCid" => "cid:missing", "traceStatus" => "committed",
              "tracedAt" => Time.now.utc.iso8601 }
    expect(RailsOsiLevel8::Intent::Validator.validate(trace).reason).to eq("intent_grounding_reference_invalid")
  end

  it "M4: intent.* PULLs work; private_local never disclosed" do
    Mission.create!(title: "T", body: "b", status: "ratified") unless Mission.exists?
    RailsOsiLevel8::Intent::Factory.seed_demo!

    m = rpc("intent.mission.get", { "active" => true })
    expect(m["ok"]).to be(true)
    expect(m.dig("result", "@type")).to eq("intent:Mission")

    st = rpc("intent.stakeholder.list", { "limit" => 50 })
    expect(st["ok"]).to be(true)
    names = (st.dig("result", "@graph") || st["result"]).map { |x| x.dig("attributes", "name") || x["name"] }
    # collection envelope may wrap as @graph
    items = st.dig("result", "@graph") || Array(st["result"])
    attr_names = items.map { |x| x.dig("attributes", "name") }.compact
    expect(attr_names).to include("Customers")
    expect(attr_names).not_to include("Secret regulators")

    denied = rpc("intent.stakeholder.list", { "ledgerScope" => ["private_local"] })
    expect(denied["ok"]).to be(false)
    expect(denied.dig("error", "reason")).to eq("ledger_scope_forbidden")
  end

  it "M5/M6: journey grounding + effect trace gate" do
    actor = Actor.create!(name: "A", role_key: "a-#{SecureRandom.hex(3)}")
    mission = Mission.create!(title: "M", body: "why", status: "ratified")
    persona = Persona.create!(name: "P", summary: "who", status: "ratified", persona_role: true)
    journey = Journey.create!(title: "J", goal: "g", scenario: "s", status: "active", primary_actor: actor)
    demo = RailsOsiLevel8::Intent::Factory.seed_demo!

    RailsOsiLevel8::Intent::Grounding.bind!(
      journey: journey,
      mission: mission,
      persona: persona,
      goal_cid: demo[:goal].cid,
      value_proposition_cid: demo[:value_proposition].cid
    )

    insp = RailsOsiLevel8::Intent::Grounding.inspect_journey(journey)
    expect(insp["missionCid"]).to be_present
    expect(insp["personaCid"]).to be_present
    expect(insp["valuePropositionCid"]).to eq(demo[:value_proposition].cid)

    ungrounded = rpc("note.create", { "title" => "no ground", "body" => "x", "intentTrace" => true },
                     opid: "op-unground-#{SecureRandom.hex(3)}")
    expect(ungrounded["ok"]).to be(false)
    expect(ungrounded.dig("error", "reason")).to eq("intent_grounding_not_active")

    grounded = rpc("note.create", {
      "title" => "grounded", "body" => "y",
      "groundingCid" => insp["groundingCid"]
    }, opid: "op-ground-#{SecureRandom.hex(3)}")
    expect(grounded["ok"]).to be(true)
    effect_cid = grounded.dig("result", "@id")
    tr = rpc("intent.trace.for_effect", { "effectCid" => effect_cid })
    expect(tr["ok"]).to be(true)
    expect(tr.dig("result", "found")).to be(true)
    expect(tr.dig("result", "trace", "traceStatus")).to eq("committed")
  end


  it "M7: persona != segment; private_local non-escape; closed predicates" do
    RailsOsiLevel8::Intent::Factory.seed_demo!
    expect(RailsOsiLevel8::Intent::MarketSegment.cross_boundary.where(kind: "segment").count).to be >= 1
    expect(defined?(Persona)).to be_truthy
    expect(ActiveRecord::Base.connection.tables).not_to include("intent_personas")

    priv = RailsOsiLevel8::Intent::Stakeholder.where(ledger_placement: "private_local").count
    expect(priv).to be >= 1
    pub = rpc("intent.stakeholder.list", {})
    items = pub.dig("result", "@graph") || Array(pub["result"])
    expect(items.all? { |i| i["ledgerPlacement"] != "private_local" }).to be(true)
  end
end
