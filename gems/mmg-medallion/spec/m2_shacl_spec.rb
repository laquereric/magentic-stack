# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M2 mmg_shacl_v1 gate" do
  def register!
    Mmg::Medallion::ShapeSet.register(
      "strict:v1",
      allow_predicates: ["mm:kind"],
      required_predicates: ["mm:kind"]
    )
    Mmg::Medallion::ShapeSet.register("loose:v1")
    Mmg::Medallion.register_flow(
      "m2_strict", source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver", shape_set: "strict:v1", version: "1"
    )
    Mmg::Medallion.register_flow(
      "m2_loose", source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver", shape_set: "loose:v1", version: "1"
    )
    Mmg::Medallion.register_flow(
      "m2_ghost", source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver", shape_set: "no-such-set", version: "1"
    )
  end

  def good
    ["<urn:mm:m:1> <mm:kind> \"observation\" ."]
  end

  before { register! }

  it "passes typed triples and stamps the v1 engine" do
    r = Mmg::Medallion.conform(flow: "m2_strict", bronze_triples: good, dry_run: true)
    expect(r[:ok]).to be(true)
    expect(r[:silver]["shacl_report"][:engine]).to eq("mmg_shacl_v1")
    expect(r[:silver]["shacl_report"][:violations]).to eq([])
    expect(r[:audit]["shacl"][:engine]).to eq("mmg_shacl_v1")
  end

  it "refuses a predicate outside the shape" do
    r = Mmg::Medallion.conform(
      flow: "m2_strict",
      bronze_triples: ["<urn:mm:m:1> <mm:whatever> \"x\" ."],
      dry_run: true
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:shacl_failed)
    expect(r[:because]).to include("mm:whatever")
    expect(r[:gate][:violations].join).to include("strict:v1")
  end

  it "refuses a missing required predicate" do
    Mmg::Medallion::ShapeSet.register("needful:v1", required_predicates: ["mm:kind"])
    Mmg::Medallion.register_flow(
      "m2_needful", source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver", shape_set: "needful:v1", version: "1"
    )
    r = Mmg::Medallion.conform(
      flow: "m2_needful",
      bronze_triples: ["<urn:mm:m:1> <mm:status> \"active\" ."],
      dry_run: true
    )
    expect(r[:ok]).to be(false)
    expect(r[:gate][:violations].join).to include("mm:kind")
  end

  it "refuses unparseable lines and blank nodes" do
    bad_line = Mmg::Medallion.conform(
      flow: "m2_loose", bronze_triples: ["this is not a triple"], dry_run: true
    )
    expect(bad_line[:ok]).to be(false)
    expect(bad_line[:gate][:violations].join).to include("not an S P O")

    bnode = Mmg::Medallion.conform(
      flow: "m2_loose", bronze_triples: ["<urn:mm:m:1> <mm:kind> _:b1 ."], dry_run: true
    )
    expect(bnode[:ok]).to be(false)
    expect(bnode[:gate][:violations].join).to include("blank node")
  end

  it "refuses an undeclared shape_set instead of guessing" do
    r = Mmg::Medallion.conform(flow: "m2_ghost", bronze_triples: good, dry_run: true)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:shacl_failed)
    expect(r[:because]).to include("unknown shape_set")
  end

  it "still refuses the empty set" do
    r = Mmg::Medallion.conform(flow: "m2_loose", bronze_triples: [], dry_run: true)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:shacl_failed)
  end

  it "answers the EngineBinding probe" do
    expect(Mmg::Medallion.shacl_v1?).to be(true)
  end
end
