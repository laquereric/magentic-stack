# frozen_string_literal: true

RSpec.describe Vv::MedallionMemory::Fact do
  let(:store) { Vv::MedallionMemory::Store.new }

  def append(**over)
    described_class.append(
      store: store, subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "manager", valid_from: "2026-01-01",
      **over
    )
  end

  it "engine-stamps tx_from from the journal position" do
    r = append
    expect(r[:ok]).to be(true)
    expect(r[:tx_from]).to eq(1)
    expect(r[:fact][:tx_to]).to be_nil
    expect(store.current_position).to eq(1)
  end

  it "refuses client-set tx_from" do
    r = append(tx_from: 99)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq("tx_time_client_set")
    expect(store.facts).to be_empty
  end

  it "refuses client-set tx_to" do
    r = append(tx_to: 99)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq("tx_time_client_set")
  end

  it "supersession closes valid_to and leaves tx_to open" do
    first = append[:fact]
    r = described_class.supersede(
      store: store, fact_id: first[:fact_id],
      object: "director", valid_from: "2026-06-01"
    )
    expect(r[:ok]).to be(true)
    expect(r[:fact][:supersedes_fact_id]).to eq(first[:fact_id])

    old = described_class.find(store: store, fact_id: first[:fact_id])
    expect(old.valid_to).to eq("2026-06-01")
    expect(old.tx_to).to be_nil
  end

  it "correction closes tx_to and leaves the world interval as written" do
    first = append[:fact]
    r = described_class.correct(store: store, fact_id: first[:fact_id], object: "manager")
    expect(r[:ok]).to be(true)
    expect(r[:fact][:corrects_fact_id]).to eq(first[:fact_id])

    old = described_class.find(store: store, fact_id: first[:fact_id])
    expect(old.tx_to).not_to be_nil
    expect(old.valid_from).to eq("2026-01-01")
    expect(old.valid_to).to be_nil
  end

  it "answers the four queries" do
    first = append[:fact]
    described_class.supersede(
      store: store, fact_id: first[:fact_id],
      object: "director", valid_from: "2026-06-01"
    )

    expect(described_class.current(store: store).map(&:object_value)).to eq(["director"])
    expect(described_class.true_on(store: store, date: "2026-03-01").map(&:object_value))
      .to eq(["manager"])
    expect(described_class.believed_on(store: store, tx: 1).map(&:object_value))
      .to include("manager")
    replay = described_class.believed_on_about(store: store, tx: 1, date: "2026-03-01")
    expect(replay.map(&:object_value)).to eq(["manager"])
  end

  it "never UPDATEs: close writes a successor row" do
    first = append[:fact]
    described_class.supersede(
      store: store, fact_id: first[:fact_id],
      object: "director", valid_from: "2026-06-01"
    )
    expect(store.facts.size).to eq(2)
  end

  it "supersede stales consumers, correct invalidates them" do
    superseded = append[:fact]
    Vv::MedallionMemory::Derivation.record(
      store: store, artefact_id: "gold:profile/1",
      artefact_kind: "semantic_profile", fact_id: superseded[:fact_id]
    )
    r = described_class.supersede(
      store: store, fact_id: superseded[:fact_id],
      object: "director", valid_from: "2026-06-01"
    )
    expect(r[:derivation][:staled]).to eq(["gold:profile/1"])
    expect(r[:derivation][:invalidated]).to eq([])

    corrected = append(object: "manger", valid_from: "2026-01-01")[:fact]
    Vv::MedallionMemory::Derivation.record(
      store: store, artefact_id: "gold:profile/2",
      artefact_kind: "semantic_profile", fact_id: corrected[:fact_id]
    )
    r2 = described_class.correct(store: store, fact_id: corrected[:fact_id], object: "manager")
    expect(r2[:derivation][:invalidated]).to eq(["gold:profile/2"])
    expect(r2[:derivation][:staled]).to eq([])
  end
end
