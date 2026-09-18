# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M10 confidence is a stamp, never a tier" do
  it "accepts exactly L1|L2|L3, canonicalised" do
    expect(Mmg::Medallion::Confidence.valid?("L1")).to be(true)
    expect(Mmg::Medallion::Confidence.valid?("l2")).to be(true)
    expect(Mmg::Medallion::Confidence.valid?("high")).to be(false)
    expect(Mmg::Medallion::Confidence.valid?(nil)).to be(false)
  end

  it "refuses a confidence name where a tier goes" do
    %w[L1 l2 confidence].each do |name|
      c = Mmg::Medallion.layer(name)
      expect(c[:ok]).to be(false)
      expect(c[:reason]).to eq(:confidence_not_a_tier)
      expect(c[:because]).to include("never a Build tier")
    end
  end

  it "still refuses unknown tiers as unknown" do
    c = Mmg::Medallion.layer("vibes")
    expect(c[:ok]).to be(false)
    expect(c[:reason]).to eq(:unknown_tier)
  end

  it "stamps facts without becoming a rank" do
    store = Mmg::Medallion::FactStore.new
    r = store.append(
      subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "manager", valid_from: "2026-01-01", confidence: "l2"
    )
    expect(r[:ok]).to be(true)
    expect(r[:fact][:confidence]).to eq("L2")
  end

  it "refuses a fact stamped with a non-level" do
    store = Mmg::Medallion::FactStore.new
    r = store.append(
      subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "manager", valid_from: "2026-01-01", confidence: "high"
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:confidence_not_a_tier)
  end

  it "answers the EngineBinding probe" do
    expect(Mmg::Medallion.confidence_is_a_stamp?).to be(true)
  end
end
