# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M5 Silver temporal validity" do
  def register!
    Mmg::Medallion::ShapeSet.register("gm:v1")
    Mmg::Medallion.register_flow(
      "m5_flow",
      source_graphs: ["urn:mm:graph:memory"],
      target_tier: "silver",
      shape_set: "gm:v1",
      version: "1"
    )
  end

  def bronze
    [
      "<urn:mm:m:1> <mm:kind> \"observation\" .",
      "<urn:mm:m:1> <mm:status> \"active\" ."
    ]
  end

  before { register! }

  describe "Conformer temporal envelope" do
    it "stamps engine tx on every silver change-set" do
      r = Mmg::Medallion.conform(flow: "m5_flow", bronze_triples: bronze, dry_run: true)
      expect(r[:ok]).to be(true)
      expect(r[:silver]["temporal"]["tx_from"]).to be_a(Integer)
      expect(r[:silver]["temporal"]["tx_to"]).to be_nil
    end

    it "carries caller world-time through unstamped" do
      r = Mmg::Medallion.conform(
        flow: "m5_flow", bronze_triples: bronze, dry_run: true,
        valid_from: "2026-09-18T00:00:00Z"
      )
      expect(r[:silver]["temporal"]["valid_from"]).to eq("2026-09-18T00:00:00Z")
    end

    it "refuses caller-set tx_from" do
      r = Mmg::Medallion.conform(
        flow: "m5_flow", bronze_triples: bronze, dry_run: true, tx_from: 42
      )
      expect(r[:ok]).to be(false)
      expect(r[:reason]).to eq(:tx_time_client_set)
    end

    it "refuses caller-set tx_to" do
      r = Mmg::Medallion.conform(
        flow: "m5_flow", bronze_triples: bronze, dry_run: true, tx_to: 42
      )
      expect(r[:ok]).to be(false)
      expect(r[:reason]).to eq(:tx_time_client_set)
    end

    it "answers the EngineBinding probe" do
      expect(Mmg::Medallion.temporal_landed?).to be(true)
    end
  end

  describe "FactStore append-and-close" do
    let(:store) { Mmg::Medallion::FactStore.new }

    it "engine-stamps tx_from and never takes one from the caller" do
      r = store.append(
        subject_iri: "urn:mm:user/1", predicate: "mm:role",
        object: "manager", valid_from: "2026-01-01"
      )
      expect(r[:ok]).to be(true)
      expect(r[:tx_from]).to eq(1)

      bad = store.append(
        subject_iri: "urn:mm:user/1", predicate: "mm:role",
        object: "manager", valid_from: "2026-01-01", tx_from: 99
      )
      expect(bad[:ok]).to be(false)
      expect(bad[:reason]).to eq(:tx_time_client_set)
    end

    it "supersession closes valid_to and leaves belief open" do
      first = store.append(
        subject_iri: "urn:mm:user/1", predicate: "mm:role",
        object: "manager", valid_from: "2026-01-01"
      )[:fact]

      r = store.supersede(fact_id: first[:fact_id], object: "director", valid_from: "2026-06-01")
      expect(r[:ok]).to be(true)
      expect(r[:fact][:supersedes_fact_id]).to eq(first[:fact_id])

      old = store.find(first[:fact_id])
      expect(old.valid_to).to eq("2026-06-01")
      expect(old.tx_to).to be_nil
    end

    it "correction closes tx_to and leaves the world interval as written" do
      first = store.append(
        subject_iri: "urn:mm:user/1", predicate: "mm:role",
        object: "manger", valid_from: "2026-01-01"
      )[:fact]

      r = store.correct(fact_id: first[:fact_id], object: "manager")
      expect(r[:ok]).to be(true)
      expect(r[:fact][:corrects_fact_id]).to eq(first[:fact_id])

      old = store.find(first[:fact_id])
      expect(old.tx_to).not_to be_nil
      expect(old.valid_from).to eq("2026-01-01")
      expect(old.valid_to).to be_nil
    end

    it "answers the four queries" do
      a = store.append(
        subject_iri: "urn:mm:user/1", predicate: "mm:role",
        object: "manager", valid_from: "2026-01-01"
      )[:fact]
      store.supersede(fact_id: a[:fact_id], object: "director", valid_from: "2026-06-01")

      expect(store.current.size).to eq(1)
      expect(store.current.first.object_value).to eq("director")

      # As of March, at current belief: the manager row.
      march = store.true_on("2026-03-01")
      expect(march.map { |f| f.object_value }).to eq(["manager"])

      # Believed at tx 1 (before the supersession landed at tx 2).
      expect(store.believed_on(1).map { |f| f.object_value }).to include("manager")
      replay = store.believed_on_about(1, "2026-03-01")
      expect(replay.map { |f| f.object_value }).to eq(["manager"])
    end

    it "never UPDATEs: close writes a successor row" do
      a = store.append(
        subject_iri: "urn:mm:user/1", predicate: "mm:role",
        object: "manager", valid_from: "2026-01-01"
      )[:fact]
      store.supersede(fact_id: a[:fact_id], object: "director", valid_from: "2026-06-01")
      expect(store.facts.size).to eq(2)
    end
  end
end
