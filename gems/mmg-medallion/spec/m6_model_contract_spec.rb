# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M6 Gold promotion requires SemanticModel + Contract" do
  def register!
    Mmg::Medallion.register_flow(
      "m6_flow",
      source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver",
      shape_set: "gm:v1",
      version: "1"
    )
  end

  def silver_cas
    c = Mmg::Medallion.conform(
      flow: "m6_flow",
      bronze_triples: ["<urn:mm:m:1> <mm:kind> \"observation\" ."],
      dry_run: true
    )
    # The armed promote consumes the conform envelope: silver rows plus
    # the gate report and the content address, the way BACKJOB would hand
    # one call's output to the next.
    c[:silver].merge("cas_digest" => c[:cas_digest], "audit" => c[:audit])
  end

  def model(**over)
    Mmg::Medallion::SemanticModel.new(
      **{ iri: "urn:mm:model/persona", version: "1", status: "governed",
          owner: "steward", definition: "persona profile" }.merge(over)
    )
  end

  def contract(**over)
    Mmg::Medallion::Contract.new(
      **{ iri: "urn:mm:contract/persona", version: "1",
          semantic_model_iri: "urn:mm:model/persona",
          shape_set_iri: "urn:mm:shapes/persona",
          freshness_sla: "P7D" }.merge(over)
    )
  end

  before { register! }

  it "leaves dry_run optional, as before" do
    r = Mmg::Medallion.promote(flow: "m6_flow", silver: silver_cas, dry_run: true)
    expect(r[:ok]).to be(true)
    expect(r[:gold]["semantic_model_iri"]).to be_nil
  end

  it "refuses an armed promote with no model" do
    r = Mmg::Medallion.promote(
      flow: "m6_flow", silver: silver_cas, dry_run: false, contract: contract
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:model_required)
  end

  it "refuses an armed promote with no contract" do
    r = Mmg::Medallion.promote(
      flow: "m6_flow", silver: silver_cas, dry_run: false, semantic_model: model
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:contract_required)
  end

  it "refuses an ungoverned model: optional is not once" do
    r = Mmg::Medallion.promote(
      flow: "m6_flow", silver: silver_cas, dry_run: false,
      semantic_model: model(status: "draft"), contract: contract
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:model_required)
    expect(r[:because]).to include("governed")
  end

  it "refuses a contract naming a different model" do
    r = Mmg::Medallion.promote(
      flow: "m6_flow", silver: silver_cas, dry_run: false,
      semantic_model: model,
      contract: contract(semantic_model_iri: "urn:mm:model/other")
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:contract_required)
  end

  it "refuses a contract with no freshness SLA" do
    r = Mmg::Medallion.promote(
      flow: "m6_flow", silver: silver_cas, dry_run: false,
      semantic_model: model, contract: contract(freshness_sla: nil)
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:contract_required)
  end

  it "arms with a governed model under its contract, and records both iris" do
    r = Mmg::Medallion.promote(
      flow: "m6_flow", silver: silver_cas, dry_run: false,
      semantic_model: model, contract: contract
    )
    expect(r[:ok]).to be(true)
    expect(r[:gold]["semantic_model_iri"]).to eq("urn:mm:model/persona")
    expect(r[:gold]["contract_iri"]).to eq("urn:mm:contract/persona")
  end

  it "accepts hashes as well as structs" do
    r = Mmg::Medallion.promote(
      flow: "m6_flow", silver: silver_cas, dry_run: false,
      semantic_model: { "iri" => "urn:mm:model/persona", "governed" => true },
      contract: { "iri" => "urn:mm:contract/persona",
                  "semantic_model_iri" => "urn:mm:model/persona",
                  "freshness_sla" => "P7D" }
    )
    expect(r[:ok]).to be(true)
  end

  it "answers the EngineBinding probe" do
    expect(Mmg::Medallion::Curator.requires_model_contract_on_arm?).to be(true)
  end
end
