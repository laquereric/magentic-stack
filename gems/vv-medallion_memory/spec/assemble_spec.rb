# frozen_string_literal: true

RSpec.describe Vv::MedallionMemory::Assemble do
  let(:store) { Vv::MedallionMemory::Store.new }
  let(:vector) { Vv::MedallionMemory::InMemoryVector.new }
  let(:fact) { Vv::MedallionMemory::Fact }

  def land!(subject_iri, predicate, object, valid_from: "2026-01-01")
    fact.append(
      store: store, subject_iri: subject_iri, predicate: predicate,
      object: object, valid_from: valid_from, canonical: true
    )[:fact]
  end

  def seed!
    land!("urn:mm:user/1", "mm:role", "manager")
    land!("urn:mm:user/1", "mm:member_of", "urn:mm:team/a")
    land!("urn:mm:team/a", "mm:name", "platform")
    land!("urn:mm:team/a", "mm:owns", "urn:mm:project/x")
    land!("urn:mm:project/x", "mm:status", "active")
    land!("urn:mm:user/2", "mm:role", "contractor")
    by_subject = store.facts.group_by(&:subject_iri)
    by_subject.each do |subject_iri, facts|
      vector.embed(subject_iri, facts.map { |f| "#{f.predicate} #{f.object_value}" }.join(" "))
    end
  end

  def pack!(cue: "platform team", **over)
    seed!
    args = { store: store, cue: cue, node_budget: 6, token_ceiling: 1000,
             as_of_tx: store.current_position, vector: vector }.merge(over)
    described_class.call(**args)
  end

  it "assembles a pack from cue, seeds, and graph walks" do
    r = pack!
    expect(r[:ok]).to be(true)
    iris = r[:subjects].map { |s| s[:subject_iri] }
    expect(iris).to include("urn:mm:team/a", "urn:mm:user/1")
    expect(r[:tokens]).to be > 0
    expect(r[:truncated]).to be(false)
    expect(r[:subjects].first.keys).to include(:subject_iri, :priority, :cost, :text)
  end

  it "same cue twice is byte-identical" do
    seed!
    args = { store: store, cue: "platform team", node_budget: 6,
             token_ceiling: 1000, as_of_tx: store.current_position, vector: vector }
    a = described_class.call(**args)
    b = described_class.call(**args)
    expect(b).to eq(a)
  end

  it "half node_budget is the priority-prefix of the larger run" do
    seed!
    args = { store: store, cue: "role status", token_ceiling: 1000,
             as_of_tx: store.current_position, vector: vector }
    big = described_class.call(**args.merge(node_budget: 4))
    small = described_class.call(**args.merge(node_budget: 2))
    # Four subjects reachable; the bound must bind, not just order.
    expect(big[:subjects].size).to eq(4)
    expect(small[:subjects].size).to eq(2)
    big_by_priority = big[:subjects].sort_by { |s| s[:priority] }
    small_by_priority = small[:subjects].sort_by { |s| s[:priority] }
    expect(small_by_priority.map { |s| s[:subject_iri] }).to eq(
      big_by_priority.first(2).map { |s| s[:subject_iri] }
    )
  end

  it "expansion pops cheapest-first: cost never decreases with priority" do
    seed!
    r = described_class.call(
      store: store, cue: "role status", node_budget: 4,
      token_ceiling: 1000, as_of_tx: store.current_position, vector: vector
    )
    costs = r[:subjects].sort_by { |s| s[:priority] }.map { |s| s[:cost] }
    expect(costs).to eq(costs.sort)
  end

  it "as_of_tx reconstructs past belief, not current facts" do
    f = land!("urn:mm:user/1", "mm:role", "manger")
    tx_then = store.current_position
    fact.correct(store: store, fact_id: f[:fact_id], object: "manager", canonical: true)

    past = described_class.call(
      store: store, cue: "role", node_budget: 4,
      token_ceiling: 1000, as_of_tx: tx_then
    )
    now = described_class.call(
      store: store, cue: "role", node_budget: 4,
      token_ceiling: 1000, as_of_tx: store.current_position
    )
    expect(past[:subjects].map { |s| s[:text] }.join).to include("manger")
    expect(now[:subjects].map { |s| s[:text] }.join).not_to include("manger")
  end

  it "refuses a replay that does not name its tx" do
    land!("urn:mm:user/1", "mm:role", "manager")
    r = described_class.call(
      store: store, cue: "manager", node_budget: 4, token_ceiling: 1000
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq("as_of_tx_required")
  end

  it "serialises until the ceiling and says so" do
    r = pack!(token_ceiling: 3)
    expect(r[:truncated]).to be(true)
    expect(r[:subjects].size).to be >= 1
    full = pack!(token_ceiling: 1000)
    expect(r[:tokens]).to be <= full[:tokens]
  end

  it "an empty cue with no seeds is an empty pack, not an error" do
    r = described_class.call(
      store: store, node_budget: 4, token_ceiling: 1000, as_of_tx: 1
    )
    expect(r[:ok]).to be(true)
    expect(r[:subjects]).to eq([])
  end
end
