# frozen_string_literal: true

RSpec.describe Vv::MedallionMemory do
  describe "Platinum is not a tier" do
    it "keeps exactly three Build tiers" do
      expect(Vv::MedallionMemory::Tier::SLUGS).to eq(%w[bronze silver gold])
    end

    it "refuses platinum by name, with the reason that makes it not a tier" do
      refusal = Vv::MedallionMemory::Tier.refuse("platinum")

      expect(refusal[:ok]).to be(false)
      expect(refusal[:reason]).to eq("platinum_not_a_tier")
      # The refusal has to carry WHY, or the next person who wants the tier
      # reads it as an oversight and removes it.
      expect(refusal[:because]).to include("no tombstone")
      expect(refusal[:because]).to include("SILVER")
    end

    it "refuses serving and working as tiers too" do
      # Serving is Consume; the live context window is volatile Bronze. Both get
      # proposed as ranks, and both would break the same guarantee.
      expect(Vv::MedallionMemory::Tier.refuse("serving")[:ok]).to be(false)
      expect(Vv::MedallionMemory::Tier.refuse("working")[:because]).to include("VOLATILE BRONZE")
    end

    it "has no successor to Gold" do
      expect(Vv::MedallionMemory::Tier.successor("bronze")).to eq("silver")
      expect(Vv::MedallionMemory::Tier.successor("silver")).to eq("gold")
      expect(Vv::MedallionMemory::Tier.successor("gold")).to be_nil
    end
  end

  describe "the cardinal sin" do
    def envelope(**over)
      Vv::MedallionMemory::Provenance.new(
        **{ session: "s1", actor: "user:1", observed_at: "2026-09-11T00:00:00Z",
            modality: "text", source_system: "transcript",
            kind: Vv::MedallionMemory::Provenance::OBSERVED }.merge(over)
      )
    end

    it "lands an observed episode that names no parent" do
      expect(envelope.landable?).to be(true)
    end

    it "refuses a derived episode stamped observed" do
      # Summarising on ingest, in the form it actually arrives: not an overwrite,
      # a laundering. After this lands nothing can tell what was said from what a
      # model said about it.
      refusal = envelope(derived_from: "urn:mm:episode/1").refusal

      expect(refusal[:reason]).to eq("bronze_mutated")
      expect(refusal[:because]).to include("may not enter the floor as source")
    end

    it "accepts the same summary landed as new inferred Bronze" do
      # The plan's escape hatch, and the only one: a summary is a Gold product
      # that may be LANDED as a new inferred episode. It may not replace a source.
      derived = envelope.derive(
        actor: "agent:reflector", derived_from: "urn:mm:episode/1",
        observed_at: "2026-09-11T01:00:00Z"
      )

      expect(derived.landable?).to be(true)
      expect(derived.kind).to eq("inferred")
      expect(derived.generation).to eq(1)
    end

    it "refuses an inferred episode that cannot name its parent" do
      refusal = envelope(kind: "inferred", generation: 1).refusal
      expect(refusal[:reason]).to eq("audit_rejected")
    end

    it "refuses an observed episode claiming a generation" do
      refusal = envelope(generation: 2).refusal
      expect(refusal[:because]).to include("generation 0 by definition")
    end
  end

  describe "the loop is circular, so the counter is bounded" do
    it "refuses inferred_unbounded past MAX_GENERATION" do
      env = Vv::MedallionMemory::Provenance.new(
        session: "s1", actor: "agent:reflector", observed_at: "2026-09-11T00:00:00Z",
        modality: "text", source_system: "reflection",
        kind: "inferred", generation: 4, derived_from: "urn:mm:episode/3"
      )

      refusal = env.refusal
      expect(refusal[:reason]).to eq("inferred_unbounded")
      expect(refusal[:because]).to include("no observed evidence underneath")
    end

    it "walks derive() up to the bound and refuses the step past it" do
      env = Vv::MedallionMemory::Provenance.new(
        session: "s1", actor: "user:1", observed_at: "t0", modality: "text",
        source_system: "transcript", kind: "observed"
      )

      3.times do |i|
        env = env.derive(actor: "agent:reflector", derived_from: "urn:mm:episode/#{i}", observed_at: "t#{i + 1}")
        expect(env.landable?).to be(true)
      end

      too_far = env.derive(actor: "agent:reflector", derived_from: "urn:mm:episode/3", observed_at: "t4")
      expect(too_far.refusal[:reason]).to eq("inferred_unbounded")
    end
  end

  describe "purpose is carried, not documented" do
    it "declares serve as Consume and forget as Operate, not as ranks" do
      expect(Vv::MedallionMemory::Flows.named("memory.serve").purpose).to eq("consume")
      expect(Vv::MedallionMemory::Flows.named("memory.forget").purpose).to eq("operate")
      expect(Vv::MedallionMemory::Flows.build_flows.map(&:name))
        .to eq(%w[memory.episode memory.conform memory.curate])
    end

    it "refuses a Consume or Operate flow that targets a Build tier" do
      # This is the specific confusion M7 exists to prevent: if a non-Build
      # purpose could wear a Build rank, Platinum would arrive as one.
      trespasser = Vv::MedallionMemory::Flow.new(
        name: "memory.sneak", source: "Silver", target: "gold",
        purpose: Vv::MedallionMemory::Purpose::OPERATE, notes: "", blocked_by: []
      )

      expect(trespasser.refusal[:reason]).to eq("audit_rejected")
      expect(trespasser.refusal[:because]).to include("what lets Platinum in")
    end

    it "refuses a Build flow targeting something that is not a tier" do
      bad = Vv::MedallionMemory::Flow.new(
        name: "memory.bad", source: "Silver", target: "platinum",
        purpose: Vv::MedallionMemory::Purpose::BUILD, notes: "", blocked_by: []
      )

      expect(bad.refusal[:reason]).to eq("platinum_not_a_tier")
    end
  end

  describe "memory.distill is refused until it can be forgotten" do
    it "blocks on temporal validity and the deletion cascade" do
      # Distilling before a tombstone can cascade means a forgotten fact can be
      # resurrected from weights with nothing downstream able to tell.
      distill = Vv::MedallionMemory::Flows.named("memory.distill")

      expect(distill.blocked?).to be(true)
      expect(distill.blocked_by).to eq(%w[M5-temporal-validity M9-deletion-cascades])
      expect(distill.refusal[:reason]).to eq("audit_rejected")
    end

    it "is the only blocked flow" do
      expect(Vv::MedallionMemory::Flows.blocked.map(&:name)).to eq(["memory.distill"])
    end
  end

  describe "the engine binding refuses until M-home is named" do
    it "refuses medallion_home_undecided with both options spelled out" do
      refusal = Vv::MedallionMemory::EngineBinding.bind!

      expect(refusal[:reason]).to eq("medallion_home_undecided")
      expect(refusal[:because]).to include("fork the projection plane")
      expect(refusal[:because]).to include("M1")
      expect(refusal[:because]).to include("M10")
    end

    it "still refuses when a home IS named, because naming is not landing" do
      # The honest answer for the moment after the decision and before M1. A
      # binding that went green on the decision alone would report an engine
      # that does not exist as wired.
      refusal = Vv::MedallionMemory::EngineBinding.bind!(home: :stack)

      expect(refusal[:ok]).to be(false)
      expect(refusal[:because]).to include("no engine change has landed")
    end

    it "carries no Conformer, Curator, or projection of its own" do
      # The non-goal, asserted against the source tree rather than trusted: a
      # private Conformer here is the fork, and the next Flow would fork it again.
      sources = Dir[File.expand_path("../lib/**/*.rb", __dir__)]
      expect(sources).not_to be_empty

      offenders = sources.select do |path|
        File.read(path).match?(/class\s+(Conformer|Curator|GraphProjection)\b/)
      end
      expect(offenders).to eq([])
    end
  end

  describe "the refusal vocabulary" do
    it "exists in full before any happy path is claimed" do
      expect(Vv::MedallionMemory::Refusal::ALL).to include(
        "bronze_mutated", "audit_rejected", "shacl_failed", "model_required",
        "contract_required", "principal_override_refused", "platinum_not_a_tier",
        "rag_write_undecided", "inferred_unbounded", "scope_violation"
      )
    end

    it "refuses to mint a reason outside the closed set" do
      result = Vv::MedallionMemory::Refusal.build("vibes_were_off", "made up on the spot")

      expect(result[:reason]).to eq("audit_rejected")
      expect(result[:because]).to include("unregistered refusal")
    end

    it "says when each reason fires" do
      Vv::MedallionMemory::Refusal::ALL.each do |reason|
        expect(Vv::MedallionMemory::Refusal::WHEN[reason]).not_to be_nil, "#{reason} has no condition"
      end
    end
  end
end
