# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M3 audit!" do
  it "exists on the engine: the doctrine is a method, not a comment" do
    expect(Mmg::Medallion.respond_to?(:audit!)).to be(true)
  end

  it "rejects a proposed fourth Build tier" do
    r = Mmg::Medallion.audit!(tier: "platinum")
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:audit_rejected)
    expect(r[:because]).to include("no tombstone")
    expect(r[:because]).to include("audit! exists to reject")
  end

  it "rejects any non-tier rank, not just the famous one" do
    r = Mmg::Medallion.audit!(tier: "serving")
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:audit_rejected)
    expect(r[:because]).to include("bronze, silver, gold")
  end

  it "rejects Bronze that transforms" do
    r = Mmg::Medallion.audit!(tier: "bronze", bronze_transforms: true)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:audit_rejected)
    expect(r[:because]).to include("raw landing")
  end

  it "rejects Silver that only copies" do
    r = Mmg::Medallion.audit!(tier: "silver", silver_copies: true)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:audit_rejected)
    expect(r[:because]).to include("only copies")
  end

  it "rejects Gold without each of model, contract, gate report, and CAS" do
    base = { tier: "gold", semantic_model: { iri: "urn:mm:model/p" },
             contract: { iri: "urn:mm:contract/p" },
             shacl_report: { ok: true }, cas_digest: "sha256:abc" }
    %w[semantic_model contract shacl_report cas_digest].each do |missing|
      r = Mmg::Medallion.audit!(base.reject { |k, _| k.to_s == missing })
      expect(r[:ok]).to be(false)
      expect(r[:reason]).to eq(:audit_rejected)
      expect(r[:because]).to include(missing)
    end
  end

  it "passes a clean Silver proposal and names its checks" do
    r = Mmg::Medallion.audit!(tier: "silver")
    expect(r[:ok]).to be(true)
    expect(r[:checks]).to include("no_fourth_tier", "silver_conforms")
  end

  it "passes an evidenced Gold proposal" do
    r = Mmg::Medallion.audit!(
      "tier" => "gold", "semantic_model" => { "iri" => "urn:mm:model/p" },
      "contract" => { "iri" => "urn:mm:contract/p" },
      "shacl_report" => { "ok" => true }, "cas_digest" => "sha256:abc"
    )
    expect(r[:ok]).to be(true)
    expect(r[:checks]).to include("gold_evidenced")
  end

  it "never raises: garbage in is a refusal out" do
    expect(Mmg::Medallion.audit!(nil)[:ok]).to be(false)
    expect(Mmg::Medallion.audit!("promote plz")[:ok]).to be(false)
    expect(Mmg::Medallion.audit!({})[:reason]).to eq(:audit_rejected)
  end

  it "strict flags: only literal true fires" do
    expect(Mmg::Medallion.audit!(tier: "bronze", bronze_transforms: "yes")[:ok]).to be(true)
  end

  describe "the armed promote is judged" do
    def register!
      Mmg::Medallion.register_flow(
        "m3_flow", source_graphs: ["urn:mm:graph:memory"],
        target_tier: "silver", shape_set: "gm:v1", version: "1"
      )
    end

    def model
      Mmg::Medallion::SemanticModel.new(
        iri: "urn:mm:model/persona", version: "1", status: "governed",
        owner: "steward", definition: "persona profile"
      )
    end

    def contract
      Mmg::Medallion::Contract.new(
        iri: "urn:mm:contract/persona", version: "1",
        semantic_model_iri: "urn:mm:model/persona",
        shape_set_iri: "urn:mm:shapes/persona", freshness_sla: "P7D"
      )
    end

    def silver_with(**over)
      c = Mmg::Medallion.conform(
        flow: "m3_flow",
        bronze_triples: ["<urn:mm:m:1> <mm:kind> \"observation\" ."],
        dry_run: true
      )
      base = c[:silver].merge("cas_digest" => c[:cas_digest], "audit" => c[:audit])
      over.each { |k, v| v.nil? ? base.delete(k.to_s) : base[k.to_s] = v }
      base
    end

    before { register! }

    it "armed promote with full evidence still passes" do
      r = Mmg::Medallion.promote(
        flow: "m3_flow", silver: silver_with, dry_run: false,
        semantic_model: model, contract: contract
      )
      expect(r[:ok]).to be(true)
    end

    it "armed promote without a gate report is refused" do
      r = Mmg::Medallion.promote(
        flow: "m3_flow", silver: silver_with(audit: nil, shacl_report: nil),
        dry_run: false, semantic_model: model, contract: contract
      )
      expect(r[:ok]).to be(false)
      expect(r[:reason]).to eq(:audit_rejected)
      expect(r[:because]).to include("shacl_report")
    end

    it "armed promote without a CAS pointer is refused" do
      r = Mmg::Medallion.promote(
        flow: "m3_flow", silver: silver_with(cas_digest: nil, cas: nil),
        dry_run: false, semantic_model: model, contract: contract
      )
      expect(r[:ok]).to be(false)
      expect(r[:reason]).to eq(:audit_rejected)
      expect(r[:because]).to include("cas_digest")
    end

    it "dry promote stays unjudged: a plan printer is not a promotion" do
      r = Mmg::Medallion.promote(flow: "m3_flow", silver: silver_with, dry_run: true)
      expect(r[:ok]).to be(true)
    end
  end
end
