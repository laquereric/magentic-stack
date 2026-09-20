# frozen_string_literal: true

require_relative "spec_helper"

class FakeSparqlSink
  attr_reader :updates

  def initialize(result: { ok: true })
    @updates = []
    @result = result
  end

  def update(sparql)
    @updates << sparql
    @result
  end
end

RSpec.describe "M1 armed SPARQL writes" do
  def register!
    Mmg::Medallion::ShapeSet.register("gm:v1")
    Mmg::Medallion.register_flow(
      "m1_flow",
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

  def envelope
    {
      session: "s1", actor: "user:1", observed_at: "2026-09-18T00:00:00Z",
      modality: "text", source_system: "transcript", kind: "observed"
    }
  end

  around do |ex|
    old = ENV.delete("MM_OXIGRAPH_URL")
    ex.run
  ensure
    ENV["MM_OXIGRAPH_URL"] = old unless old.nil?
  end

  before do
    register!
    Mmg::Medallion::GraphProjection.clear!
  end

  it "armed conform writes the named silver graph to the projection" do
    r = Mmg::Medallion.conform(
      flow: "m1_flow", bronze_triples: bronze,
      dry_run: false, provenance: envelope, graph_sink: nil
    )
    expect(r[:ok]).to be(true)
    expect(r[:silver]["write"][:sinks]).to eq(["projection"])
    expect(r[:silver]["write"][:triples]).to eq(2)
    expect(r[:cas_digest]).to start_with("sha256:")
    expect(r[:because]).to include("projection")

    snap = Mmg::Medallion::GraphProjection.new.snapshot(graph_iri: r[:silver]["target_graph"])
    expect(snap[:triples].size).to eq(2)
  end

  it "an injected sink receives INSERT DATA for the graph" do
    fake = FakeSparqlSink.new
    r = Mmg::Medallion.conform(
      flow: "m1_flow", bronze_triples: bronze,
      dry_run: false, provenance: envelope, graph_sink: fake
    )
    expect(r[:ok]).to be(true)
    expect(r[:silver]["write"][:sinks]).to include("projection", "oxigraph")
    expect(fake.updates.size).to eq(1)
    expect(fake.updates.first).to include("INSERT DATA")
    expect(fake.updates.first).to include(r[:silver]["target_graph"])
    expect(fake.updates.first).to include(bronze.first)
  end

  it "a failing sink fails the run: configured sinks never skip" do
    fake = FakeSparqlSink.new(result: { ok: false, reason: :update_failed, because: "HTTP 500" })
    r = Mmg::Medallion.conform(
      flow: "m1_flow", bronze_triples: bronze,
      dry_run: false, provenance: envelope, graph_sink: fake
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:graph_write_failed)
  end

  it "dry runs still write nothing" do
    fake = FakeSparqlSink.new
    r = Mmg::Medallion.conform(
      flow: "m1_flow", bronze_triples: bronze, dry_run: true, graph_sink: fake
    )
    expect(r[:ok]).to be(true)
    expect(r[:silver].key?("write")).to be(false)
    expect(fake.updates).to be_empty
  end

  it "armed promote writes the gold graph and links the gate report" do
    c = Mmg::Medallion.conform(
      flow: "m1_flow", bronze_triples: bronze,
      dry_run: false, provenance: envelope, graph_sink: nil
    )
    silver = c[:silver].merge("cas_digest" => c[:cas_digest], "audit" => c[:audit])
    fake = FakeSparqlSink.new
    p = Mmg::Medallion.promote(
      flow: "m1_flow", silver: silver,
      semantic_model: { "iri" => "urn:mm:model/p", "governed" => true },
      contract: { "iri" => "urn:mm:contract/p", "semantic_model_iri" => "urn:mm:model/p",
                  "freshness_sla" => "P7D" },
      dry_run: false, graph_sink: fake
    )
    expect(p[:ok]).to be(true)
    expect(p[:gold]["write"][:sinks]).to include("projection", "oxigraph")
    expect(p[:gold]["shacl_report"][:engine]).to eq("mmg_shacl_v1")
    expect(fake.updates.first).to include(p[:gold]["target_graph"])
  end

  it "answers the EngineBinding probe" do
    expect(Mmg::Medallion.armed_writes_wired?).to be(true)
  end
end
