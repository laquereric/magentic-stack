# frozen_string_literal: true

RSpec.describe "M10 confidence is a stamp, never a tier" do
  let(:store) { Vv::MedallionMemory::Store.new }

  it "refuses confidence names where a tier goes" do
    %w[L1 l2 confidence].each do |name|
      refusal = Vv::MedallionMemory::Tier.refuse(name)
      expect(refusal[:ok]).to be(false)
      expect(refusal[:reason]).to eq("confidence_not_a_tier")
      expect(refusal[:because]).to include("never a Build tier")
    end
  end

  it "still refuses unknown tiers as unknown" do
    refusal = Vv::MedallionMemory::Tier.refuse("vibes")
    expect(refusal[:reason]).to eq("audit_rejected")
  end

  it "stamps facts canonical without becoming a rank" do
    r = Vv::MedallionMemory::Fact.append(
      store: store, subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "manager", valid_from: "2026-01-01", confidence: "l2"
    )
    expect(r[:ok]).to be(true)
    expect(r[:fact][:confidence]).to eq("L2")
  end

  it "leaves unstamped facts unstamped" do
    r = Vv::MedallionMemory::Fact.append(
      store: store, subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "manager", valid_from: "2026-01-01"
    )
    expect(r[:ok]).to be(true)
    expect(r[:fact].key?(:confidence)).to be(false)
  end

  it "refuses a non-level stamp on append, supersede, and correct" do
    bad = Vv::MedallionMemory::Fact.append(
      store: store, subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "manager", valid_from: "2026-01-01", confidence: "high"
    )
    expect(bad[:ok]).to be(false)
    expect(bad[:reason]).to eq("confidence_not_a_tier")

    good = Vv::MedallionMemory::Fact.append(
      store: store, subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "manager", valid_from: "2026-01-01"
    )[:fact]

    expect(Vv::MedallionMemory::Fact.supersede(
      store: store, fact_id: good[:fact_id],
      object: "director", valid_from: "2026-06-01", confidence: "certain"
    )[:reason]).to eq("confidence_not_a_tier")

    expect(Vv::MedallionMemory::Fact.correct(
      store: store, fact_id: good[:fact_id],
      object: "manager", confidence: "certain"
    )[:reason]).to eq("confidence_not_a_tier")
  end

  it "registers the reason in the closed vocabulary" do
    expect(Vv::MedallionMemory::Refusal::ALL).to include("confidence_not_a_tier")
  end
end
