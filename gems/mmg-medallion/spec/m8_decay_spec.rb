# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M8 per-tier decay policy" do
  it "binds every tier's slogan to a distinct clock" do
    bronze = Mmg::Medallion::Decay.policy("bronze")
    silver = Mmg::Medallion::Decay.policy("silver")
    gold = Mmg::Medallion::Decay.policy("gold")

    expect(bronze[:clock]).to eq("legal_retention")
    expect(silver[:clock]).to eq("contradiction_supersession")
    expect(gold[:clock]).to eq("utility")
  end

  it "refuses a policy for a tier that does not exist" do
    r = Mmg::Medallion::Decay.policy("platinum")
    expect(r[:ok]).to be(false)
  end

  it "a Bronze forget without retention evidence is refused" do
    gate = Mmg::Medallion::Decay.evidence_refusal(tier: "bronze", evidence: nil)
    expect(gate[:ok]).to be(false)
    expect(gate[:reason]).to eq(:audit_rejected)
    expect(gate[:because]).to include("legal_retention")
  end

  it "a Bronze forget with basis and decider passes the clock" do
    gate = Mmg::Medallion::Decay.evidence_refusal(
      tier: "bronze",
      evidence: { retention_basis: "steward_request", decided_by: "user:1" }
    )
    expect(gate).to be_nil
  end

  it "a Silver close names its successor or contradiction" do
    expect(
      Mmg::Medallion::Decay.evidence_refusal(
        tier: "silver", evidence: { superseding_fact_id: "fact_2" }
      )
    ).to be_nil

    gate = Mmg::Medallion::Decay.evidence_refusal(tier: "silver", evidence: {})
    expect(gate[:ok]).to be(false)
    expect(gate[:because]).to include("contradiction_supersession")
  end

  it "the forget walk enforces the Bronze clock" do
    refused = Mmg::Medallion.cascade(iris: ["urn:mm:episode/9"], kind: :forget)
    expect(refused[:ok]).to be(false)
    expect(refused[:reason]).to eq(:audit_rejected)

    r = Mmg::Medallion.cascade(
      iris: ["urn:mm:episode/9"], kind: :forget,
      evidence: { retention_basis: "steward_request", decided_by: "user:1" }
    )
    expect(r[:ok]).to be(true)
    expect(r[:gold]).to eq("tombstoned")
  end

  it "supersession and correction need no extra evidence: the row is the evidence" do
    expect(Mmg::Medallion.cascade(iris: ["urn:mm:user/1"], kind: :supersession)[:ok]).to be(true)
    expect(Mmg::Medallion.cascade(iris: ["urn:mm:user/1"], kind: :correction)[:ok]).to be(true)
  end

  it "answers the EngineBinding probe" do
    expect(Mmg::Medallion.decay_bound?).to be(true)
  end
end
