# frozen_string_literal: true

RSpec.describe Vv::MedallionMemory::Derivation do
  let(:store) { Vv::MedallionMemory::Store.new }

  def land_fact(object: "manager")
    Vv::MedallionMemory::Fact.append(
      store: store, subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: object, valid_from: "2026-01-01", canonical: true
    )[:fact]
  end

  def consume(fact_id, n)
    n.times.map do |i|
      described_class.record(
        store: store, artefact_id: "gold:artefact/#{fact_id}/#{i}",
        artefact_kind: "semantic_profile", fact_id: fact_id,
        derivation_run_id: "run-1"
      )
      "gold:artefact/#{fact_id}/#{i}"
    end
  end

  # The independence test: if correction and supersession behave the same,
  # the axes are not independent and the M5 work was decoration.
  it "correcting a fact INVALIDATES its three Gold consumers" do
    fact = land_fact(object: "manger")
    ids = consume(fact[:fact_id], 3)

    r = described_class.cascade(store: store, fact_id: fact[:fact_id], kind: :correction)
    expect(r[:ok]).to be(true)
    expect(r[:invalidated].sort).to eq(ids.sort)
    expect(r[:staled]).to eq([])
    ids.each do |id|
      expect(described_class.status(store: store, artefact_id: id)).to eq("invalidated")
    end
  end

  it "superseding a fact with the same three consumers STALES none-invalidated" do
    fact = land_fact
    ids = consume(fact[:fact_id], 3)

    r = described_class.cascade(store: store, fact_id: fact[:fact_id], kind: :supersession)
    expect(r[:ok]).to be(true)
    expect(r[:staled].sort).to eq(ids.sort)
    expect(r[:invalidated]).to eq([])
    ids.each do |id|
      expect(described_class.status(store: store, artefact_id: id)).to eq("stale")
    end
  end

  it "forget invalidates like a correction" do
    fact = land_fact
    ids = consume(fact[:fact_id], 2)

    r = described_class.cascade(store: store, fact_id: fact[:fact_id], kind: :forget)
    expect(r[:invalidated].sort).to eq(ids.sort)
  end

  it "a distilled adapter has no derivation rows to walk" do
    r = described_class.cascade(store: store, fact_id: "fact_nope", kind: :correction)
    expect(r[:ok]).to be(true)
    expect(r[:invalidated]).to eq([])
    expect(r[:staled]).to eq([])
  end

  it "refuses an unknown cascade kind" do
    fact = land_fact
    r = described_class.cascade(store: store, fact_id: fact[:fact_id], kind: :vibes)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq("audit_rejected")
  end

  it "records every Gold write with its consumed fact" do
    fact = land_fact
    r = described_class.record(
      store: store, artefact_id: "gold:profile/1",
      artefact_kind: "semantic_profile", fact_id: fact[:fact_id]
    )
    expect(r[:ok]).to be(true)
    expect(described_class.for_fact(store: store, fact_id: fact[:fact_id]).size).to eq(1)
  end
end
