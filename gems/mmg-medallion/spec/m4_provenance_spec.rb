# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M4 Bronze provenance stamps" do
  def register!
    Mmg::Medallion.register_flow(
      "m4_flow",
      source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver",
      shape_set: "gm:v1",
      version: "1"
    )
  end

  def bronze
    [
      "<urn:mm:m:1> <mm:kind> \"observation\" .",
      "<urn:mm:m:1> <mm:status> \"active\" ."
    ]
  end

  def envelope(**over)
    {
      session: "s1", actor: "user:1", observed_at: "2026-09-15T00:00:00Z",
      modality: "text", source_system: "transcript", kind: "observed"
    }.merge(over)
  end

  before { register! }

  it "allows a dry plan with no provenance" do
    r = Mmg::Medallion.conform(flow: "m4_flow", bronze_triples: bronze, dry_run: true)
    expect(r[:ok]).to be(true)
    expect(r[:silver]["provenance"]).to be_nil
  end

  it "refuses a land (dry_run: false) with no provenance" do
    r = Mmg::Medallion.conform(flow: "m4_flow", bronze_triples: bronze, dry_run: false)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:audit_rejected)
    expect(r[:because]).to include("required to land")
  end

  it "stamps a valid envelope onto silver" do
    r = Mmg::Medallion.conform(
      flow: "m4_flow", bronze_triples: bronze, dry_run: false, provenance: envelope
    )
    expect(r[:ok]).to be(true)
    expect(r[:silver]["provenance"][:kind]).to eq("observed")
    expect(r[:silver]["provenance"][:session]).to eq("s1")
  end

  it "refuses derived text wearing an observed stamp" do
    r = Mmg::Medallion.conform(
      flow: "m4_flow", bronze_triples: bronze, dry_run: false,
      provenance: envelope(derived_from: "urn:mm:episode/1")
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:bronze_mutated)
    expect(r[:because]).to include("may not enter the floor as source")
  end

  it "accepts the same summary as inferred Bronze" do
    r = Mmg::Medallion.conform(
      flow: "m4_flow", bronze_triples: bronze, dry_run: false,
      provenance: envelope(kind: "inferred", generation: 1, derived_from: "urn:mm:episode/1",
                           actor: "agent:reflector", source_system: "reflection")
    )
    expect(r[:ok]).to be(true)
    expect(r[:silver]["provenance"][:kind]).to eq("inferred")
    expect(r[:silver]["provenance"][:generation]).to eq(1)
  end

  it "answers the EngineBinding probe" do
    expect(Mmg::Medallion.provenance_required_on_land?).to be(true)
  end
end
