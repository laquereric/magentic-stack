# frozen_string_literal: true

RSpec.describe Vv::MedallionMemory::Branch do
  let(:store) { Vv::MedallionMemory::Store.new }
  let(:fact) { Vv::MedallionMemory::Fact }
  let(:vector) { Vv::MedallionMemory::InMemoryVector.new(store: store) }

  def open_branch(agent: "agent:a", task: "task-1")
    described_class.open(store: store, agent_id: agent, task_id: task)[:branch_id]
  end

  def steward_land!(subject_iri, predicate, object, valid_from: "2026-01-01")
    fact.append(
      store: store, subject_iri: subject_iri, predicate: predicate,
      object: object, valid_from: valid_from, canonical: true
    )[:fact]
  end

  def embed_subject!(subject_iri)
    text = store.facts.select { |f| f.subject_iri == subject_iri && f.branch_id.nil? }
                 .map { |f| "#{f.predicate} #{f.object_value}" }.join(" ")
    vector.embed(subject_iri, text)
  end

  it "a direct canonical write refuses, on every writer" do
    r = fact.append(
      store: store, subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "manager", valid_from: "2026-01-01"
    )
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq("canonical_write_refused")

    base = steward_land!("urn:mm:user/1", "mm:role", "manager")
    expect(fact.supersede(store: store, fact_id: base[:fact_id], object: "x", valid_from: "2026-02-01")[:reason])
      .to eq("canonical_write_refused")
    expect(fact.correct(store: store, fact_id: base[:fact_id], object: "y")[:reason])
      .to eq("canonical_write_refused")
  end

  it "poison on agent A's branch is invisible to agent B everywhere" do
    steward_land!("urn:mm:user/1", "mm:role", "manager")
    embed_subject!("urn:mm:user/1")

    br_a = open_branch(agent: "agent:a")
    described_class.propose(
      store: store, branch_id: br_a, op: "append",
      subject_iri: "urn:mm:claim/x", predicate: "mm:says",
      object: "malicious instructions", valid_from: "2026-01-01"
    )
    br_b = open_branch(agent: "agent:b")

    expect(fact.current(store: store).map { |f| f.subject_iri }).not_to include("urn:mm:claim/x")
    expect(fact.current(store: store, branch_id: br_b).map { |f| f.subject_iri })
      .not_to include("urn:mm:claim/x")
    expect(fact.current(store: store, branch_id: br_a).map { |f| f.subject_iri })
      .to include("urn:mm:claim/x")

    b_view = Vv::MedallionMemory::Assemble.call(
      store: store, cue: "malicious", node_budget: 6, token_ceiling: 1000,
      as_of_tx: store.current_position, branch_id: br_b
    )
    expect(b_view[:subjects].map { |s| s[:subject_iri] }).not_to include("urn:mm:claim/x")

    expect(vector.search("malicious").keys).not_to include("urn:mm:claim/x")
  end

  it "reject leaves no embedding, no edge, no live fact" do
    br_a = open_branch(agent: "agent:a")
    described_class.propose(
      store: store, branch_id: br_a, op: "append",
      subject_iri: "urn:mm:claim/x", predicate: "mm:says",
      object: "malicious instructions", valid_from: "2026-01-01"
    )

    r = described_class.merge(
      store: store, branch_id: br_a, reviewer: "steward:1",
      decision: "reject", rationale: "poisoned source"
    )
    expect(r[:ok]).to be(true)
    expect(r[:decision]).to eq("rejected")

    expect(fact.current(store: store, branch_id: br_a)).to be_empty
    expect(vector.search("malicious").keys).not_to include("urn:mm:claim/x")
    asm = Vv::MedallionMemory::Assemble.call(
      store: store, cue: "malicious", node_budget: 6, token_ceiling: 1000,
      as_of_tx: store.current_position, branch_id: br_a
    )
    expect(asm[:subjects]).to be_empty
    expect(store.rejection_rate("agent:a")).to eq(1.0)
  end

  it "embed before merge refuses unmerged_embed; merge embeds" do
    br_a = open_branch(agent: "agent:a")
    described_class.propose(
      store: store, branch_id: br_a, op: "append",
      subject_iri: "urn:mm:project/y", predicate: "mm:name",
      object: "secret project", valid_from: "2026-01-01"
    )

    refused = vector.embed("urn:mm:project/y", "secret project")
    expect(refused[:ok]).to be(false)
    expect(refused[:reason]).to eq("unmerged_embed")

    m = described_class.merge(store: store, branch_id: br_a, vector: vector)
    expect(m[:decision]).to eq("merged")
    expect(vector.search("secret project").keys).to include("urn:mm:project/y")
  end

  it "clean new facts auto-merge and land canonical" do
    br_a = open_branch(agent: "agent:a")
    described_class.propose(
      store: store, branch_id: br_a, op: "append",
      subject_iri: "urn:mm:team/b", predicate: "mm:name",
      object: "infra", valid_from: "2026-01-01"
    )

    m = described_class.merge(store: store, branch_id: br_a, vector: vector)
    expect(m[:ok]).to be(true)
    expect(m[:decision]).to eq("merged")
    expect(fact.current(store: store).map { |f| f.subject_iri }).to include("urn:mm:team/b")
    expect(vector.search("infra").keys).to include("urn:mm:team/b")
  end

  it "contradiction needs review; approval lands it" do
    steward_land!("urn:mm:user/1", "mm:role", "manager")
    br_a = open_branch(agent: "agent:a")
    described_class.propose(
      store: store, branch_id: br_a, op: "append",
      subject_iri: "urn:mm:user/1", predicate: "mm:role",
      object: "director", valid_from: "2026-03-01"
    )

    held = described_class.merge(store: store, branch_id: br_a)
    expect(held[:decision]).to eq("review_required")
    expect(held[:reasons].join).to include("contradiction")
    expect(fact.current(store: store).map { |f| f.object_value }).to eq(["manager"])

    approved = described_class.merge(
      store: store, branch_id: br_a, reviewer: "steward:1",
      decision: "approve", rationale: "promotion confirmed"
    )
    expect(approved[:decision]).to eq("approved")
    expect(approved[:conflicts_resolved].join).to include("contradiction")
  end

  it "supersede merges cleanly, and stales on merge -- not before" do
    base = steward_land!("urn:mm:user/1", "mm:role", "manager")
    Vv::MedallionMemory::Derivation.record(
      store: store, artefact_id: "gold:profile/1",
      artefact_kind: "semantic_profile", fact_id: base[:fact_id]
    )

    br_a = open_branch(agent: "agent:a")
    described_class.propose(
      store: store, branch_id: br_a, op: "supersede", base_fact_id: base[:fact_id],
      object: "director", valid_from: "2026-06-01"
    )

    live = fact.find(store: store, fact_id: base[:fact_id])
    expect(live.valid_to).to be_nil
    expect(Vv::MedallionMemory::Derivation.status(store: store, artefact_id: "gold:profile/1"))
      .to eq("valid")

    m = described_class.merge(store: store, branch_id: br_a)
    expect(m[:decision]).to eq("merged")
    expect(fact.find(store: store, fact_id: base[:fact_id]).valid_to).to eq("2026-06-01")
    expect(Vv::MedallionMemory::Derivation.status(store: store, artefact_id: "gold:profile/1"))
      .to eq("stale")
  end

  it "retraction always reviews; approval tombstones belief" do
    base = steward_land!("urn:mm:user/1", "mm:role", "manager")
    br_a = open_branch(agent: "agent:a")
    described_class.propose(store: store, branch_id: br_a, op: "retract", base_fact_id: base[:fact_id])

    held = described_class.merge(store: store, branch_id: br_a)
    expect(held[:decision]).to eq("review_required")
    expect(held[:reasons].join).to include("deletion_always_reviewed")

    approved = described_class.merge(
      store: store, branch_id: br_a, reviewer: "steward:1",
      decision: "approve", rationale: "GDPR request"
    )
    expect(approved[:decision]).to eq("approved")
    expect(fact.current(store: store)).to be_empty
  end

  it "a hot writer cannot auto-merge, but a human still can" do
    2.times do |i|
      br = open_branch(agent: "agent:hot", task: "task-#{i}")
      described_class.propose(
        store: store, branch_id: br, op: "append",
        subject_iri: "urn:mm:claim/#{i}", predicate: "mm:says",
        object: "spam", valid_from: "2026-01-01"
      )
      described_class.merge(store: store, branch_id: br, reviewer: "steward:1",
                            decision: "reject", rationale: "spam")
    end

    br = open_branch(agent: "agent:hot", task: "task-2")
    described_class.propose(
      store: store, branch_id: br, op: "append",
      subject_iri: "urn:mm:team/clean", predicate: "mm:name",
      object: "clean", valid_from: "2026-01-01"
    )
    held = described_class.merge(store: store, branch_id: br)
    expect(held[:decision]).to eq("review_required")
    expect(held[:reasons]).to include("writer_rejection_rate_above_threshold")

    approved = described_class.merge(
      store: store, branch_id: br, reviewer: "steward:1",
      decision: "approve", rationale: "verified clean"
    )
    expect(approved[:decision]).to eq("approved")
  end

  it "sensitive subjects always review" do
    store.sensitive_subjects << "urn:mm:user/1"
    br_a = open_branch(agent: "agent:a")
    described_class.propose(
      store: store, branch_id: br_a, op: "append",
      subject_iri: "urn:mm:user/1", predicate: "mm:nickname",
      object: "boss", valid_from: "2026-01-01"
    )
    held = described_class.merge(store: store, branch_id: br_a)
    expect(held[:decision]).to eq("review_required")
    expect(held[:reasons].join).to include("high_sensitivity_subject")
  end

  it "abandoned branches close their rows and reap by age" do
    br_a = open_branch(agent: "agent:a")
    described_class.propose(
      store: store, branch_id: br_a, op: "append",
      subject_iri: "urn:mm:claim/x", predicate: "mm:says",
      object: "draft", valid_from: "2026-01-01"
    )

    a = described_class.abandon(store: store, branch_id: br_a)
    expect(a[:status]).to eq("abandoned")
    expect(fact.current(store: store, branch_id: br_a)).to be_empty

    expect(described_class.reap(store: store, older_than: 100)[:reaped]).to eq([])
    expect(described_class.reap(store: store, older_than: 0)[:reaped]).to eq([br_a])
    expect(described_class.find(store: store, branch_id: br_a)).to be_nil
  end

  it "registers the new reasons in the closed vocabulary" do
    expect(Vv::MedallionMemory::Refusal::ALL).to include(
      "canonical_write_refused", "unmerged_embed"
    )
  end
end
