# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M7 purpose carried on Flow" do
  it "defaults a registered flow to build" do
    f = Mmg::Medallion.register_flow(
      "m7_build", target_tier: "silver", shape_set: "gm:v1"
    )
    expect(f.purpose).to eq("build")
    expect(f.build?).to be(true)
    expect(f.refusal).to be_nil
    expect(f.contract[:purpose]).to eq("build")
  end

  it "carries consume without making it a rank" do
    f = Mmg::Medallion::Flow.new(
      "memory.serve", source_graphs: ["urn:mm:gold"], target_tier: "context_frame",
      purpose: Mmg::Medallion::Purpose::CONSUME
    )
    expect(f.purpose).to eq("consume")
    expect(f.build?).to be(false)
    expect(f.refusal).to be_nil
  end

  it "refuses a Consume flow that targets a Build tier" do
    f = Mmg::Medallion::Flow.new(
      "memory.sneak", target_tier: "gold",
      purpose: Mmg::Medallion::Purpose::OPERATE
    )
    expect(f.refusal[:ok]).to be(false)
    expect(f.refusal[:reason]).to eq(:audit_rejected)
    expect(f.refusal[:because]).to include("what lets Platinum in")
  end

  it "refuses a Build flow targeting platinum by name" do
    f = Mmg::Medallion::Flow.new(
      "memory.bad", target_tier: "platinum",
      purpose: Mmg::Medallion::Purpose::BUILD
    )
    expect(f.refusal[:reason]).to eq(:platinum_not_a_tier)
    expect(f.refusal[:because]).to include("no tombstone")
  end

  it "does not add purpose as a fourth Build tier" do
    expect(Mmg::Medallion.layer("consume")[:ok]).to be(false)
    expect(Mmg::Medallion::Tier.for("operate")).to be_nil
  end
end
