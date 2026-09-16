# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "spec_helper"

RSpec.describe Mmg::Medallion do
  it "has a version" do
    expect(described_class.version).to match(/\d+\.\d+\.\d+/)
  end

  it "exposes bronze/silver/gold layer contracts" do
    b = described_class.layer("bronze")
    expect(b[:ok]).to be true
    expect(b[:role]).to eq("raw_admit")
    expect(described_class.retention_hint("gold")).to eq("retain_unless_governed")
    expect(described_class.layer("platinum")[:ok]).to be false
  end

  it "registers a flow and plans dry projection" do
    f = described_class.register_flow(
      "graph_memory_bronze_to_silver",
      source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver",
      shape_set: "gm:v1",
      version: "1"
    )
    expect(f.name).to eq("graph_memory_bronze_to_silver")
    plan = f.plan_projection
    expect(plan[:ok]).to be true
    expect(plan[:dry_run]).to be true
    expect(plan[:to]).to include("silver")
  end

  it "lists deprecation entries for vv-medallion" do
    d = described_class.deprecation
    expect(d[:ok]).to be true
    expect(d[:deprecated]).to include("vv-medallion")
  end

  it "conforms bronze triples to silver (dry) and promotes gold" do
    described_class.register_flow(
      "gm_memory",
      source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver",
      shape_set: "gm:v1",
      version: "2"
    )
    bronze = [
      "<urn:mm:m:1> <mm:kind> \"observation\" .",
      "<urn:mm:m:1> <mm:status> \"active\" ."
    ]
    c = described_class.conform(
      flow: "gm_memory",
      bronze_triples: bronze,
      quality: 0.9,
      dry_run: true
    )
    expect(c[:ok]).to be true
    expect(c[:silver]["tier"]).to eq("silver")
    expect(c[:cas_digest]).to start_with("sha256:")

    p = described_class.promote(
      flow: "gm_memory",
      silver: c[:silver].merge("cas_digest" => c[:cas_digest]),
      curation_id: "cur-1",
      dry_run: true
    )
    expect(p[:ok]).to be true
    expect(p[:gold]["tier"]).to eq("gold")
    expect(p[:gold]["curation_id"]).to eq("cur-1")
  end

  it "refuses empty bronze under SHACL gate" do
    described_class.register_flow("empty_flow", target_tier: "silver", shape_set: "x")
    r = described_class.conform(flow: "empty_flow", bronze_triples: [], dry_run: true)
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:shacl_failed)
  end
end
