# frozen_string_literal: true

require "spec_helper"

RSpec.describe "P10.M1 canonical reconciliation" do
  def seed!
    actor = Actor.create!(name: "Op", role_key: "op-#{SecureRandom.hex(3)}")
    mission = Mission.create!(title: "M", body: "why", status: "ratified")
    persona = Persona.create!(name: "P", summary: "who", status: "ratified", persona_role: true)
    journey = Journey.create!(title: "J", goal: "g", scenario: "s", status: "active", primary_actor: actor)
    [mission, persona, journey]
  end

  it "projects deterministic CIDs without intent_* duplicate tables" do
    mission, persona, journey = seed!

    tables = ActiveRecord::Base.connection.tables
    expect(tables).to include("missions", "visions", "personas", "actors", "journeys", "flows")
    expect(tables.grep(/intent_mission|intent_persona|intent_journey|intent_flow/)).to be_empty

    m1 = RailsOsiLevel8::Intent::Projection.for(mission)
    m2 = RailsOsiLevel8::Intent::Projection.for(Mission.find(mission.id))
    expect(m1["cid"]).to eq(m2["cid"])
    expect(m1["@type"]).to eq("intent:Mission")
    expect(m1["profileId"]).to eq("osi-level-8/profile-10")
    expect(m1["digest"]).to match(/\Asha256:[0-9a-f]{64}\z/)

    p = RailsOsiLevel8::Intent::Projection.for(persona)
    expect(p["@type"]).to eq("intent:Persona")
    expect(p["cid"]).to start_with("cid:sha256:")

    j = RailsOsiLevel8::Intent::Projection.for(journey)
    expect(j["@type"]).to eq("c4:Journey")

    # Changing intrinsic content yields a different digest/CID (append-only revision semantics)
    mission.update!(body: "why-changed")
    m3 = RailsOsiLevel8::Intent::Projection.for(mission)
    expect(m3["cid"]).not_to eq(m1["cid"])
  end
end
