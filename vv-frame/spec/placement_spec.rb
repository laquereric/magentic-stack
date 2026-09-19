# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Frame::Placement do
  def place(**kw)
    described_class.new(**{ layer: "gems", phase: "expand", rung: 2,
                            evidence: "silver", instrument: "rung" }.merge(kw))
  end

  it "accepts a placement whose axes agree" do
    expect(place.findings).to be_empty
    expect(place).to be_legal
  end

  describe "evidence gates rung climb" do
    it "refuses a rung-3 freeze held up by Bronze" do
      p = place(layer: "grammar", phase: "extract", rung: 3, evidence: "bronze")
      f = p.findings.find { |x| x[:test] == :evidence_gates_rung }
      expect(f).not_to be_nil
      expect(f[:finding]).to include("wants gold evidence")
      expect(f[:suggested_resolution]).to eq("gather the evidence, or freeze lower")
    end

    it "allows evidence stronger than the rung requires" do
      p = place(layer: "overlay", phase: "explore", rung: 1, evidence: "gold")
      expect(p.findings.map { |x| x[:test] }).not_to include(:evidence_gates_rung)
    end

    it "is the same rule at every rung" do
      expect(place(rung: 0, evidence: "bronze").evidence_supports_rung?).to be(true)
      expect(place(rung: 2, evidence: "bronze").evidence_supports_rung?).to be(false)
      expect(place(rung: 4, evidence: "silver").evidence_supports_rung?).to be(false)
      expect(place(rung: 4, evidence: "gold").evidence_supports_rung?).to be(true)
    end
  end

  describe "layer and rung are the same ordinal" do
    it "flags an overlay freezing at a substrate rung" do
      p = place(layer: "overlay", phase: "explore", rung: 4, evidence: "gold")
      f = p.findings.find { |x| x[:test] == :rung_at_home }
      expect(f[:suggested_resolution]).to eq("move the work, not the gate")
    end

    it "flags Explore work landing in the grammar layer" do
      p = place(layer: "grammar", phase: "explore", rung: 4, evidence: "gold")
      expect(p.findings.map { |x| x[:test] }).to include(:phase_at_home)
    end
  end

  it "reports every disagreement, not the first" do
    p = place(layer: "grammar", phase: "explore", rung: 0, evidence: "bronze")
    expect(p.findings.map { |x| x[:test] }).to include(:rung_at_home, :phase_at_home)
  end

  describe "holds_open — the declared exception" do
    # Explore work deliberately held inside a substrate layer, at a rung below
    # that layer's home, by a gate of its own. The legal form of failure mode 4.

    def held(gated:)
      described_class.from({ "layer" => "gems", "phase" => "explore",
                             "freezes_at_rung" => 0, "evidence" => "bronze",
                             "instrument" => "rung", "holds_open" => true },
                           gated: gated)
    end

    it "suppresses the two home findings when a gate holds the question open" do
      p = held(gated: true)
      expect(p).to be_holds_open
      expect(p.findings).to be_empty
      expect(p.to_h).to include(holds_open: true)
    end

    it "PLANT: a declaration with no gate is itself a finding" do
      p = held(gated: false)
      f = p.findings.find { |x| x[:test] == :holds_open_without_a_gate }
      expect(f).not_to be_nil
      expect(f[:suggested_resolution]).to eq("name the check in enforced_by, or drop the declaration")
    end

    it "does not suspend the evidence rule: holding a question open is not a licence to freeze" do
      p = described_class.from({ "layer" => "gems", "phase" => "explore",
                                 "freezes_at_rung" => 3, "evidence" => "bronze",
                                 "instrument" => "rung", "holds_open" => true },
                               gated: true)
      expect(p.findings.map { |x| x[:test] }).to include(:evidence_gates_rung)
    end

    it "is absent unless declared" do
      expect(place).not_to be_holds_open
      expect(place.to_h).not_to have_key(:holds_open)
    end
  end

  describe "tooling is not repo" do
    # A charter and a bin/ layout do not cost the same to reverse. They were
    # one layer once, and the checks disagreed with themselves because of it.
    it "accepts repo machinery at a low rung" do
      expect(described_class.new(layer: "tooling", phase: "expand", rung: 1,
                                 evidence: "bronze", instrument: "ledger").findings).to be_empty
    end

    it "still flags boundary doctrine freezing low" do
      p = described_class.new(layer: "repo", phase: "extract", rung: 1,
                              evidence: "bronze", instrument: "ledger")
      expect(p.findings.map { |x| x[:test] }).to include(:rung_at_home)
    end
  end

  it "names an axis value outside its closed set rather than guessing" do
    p = place(instrument: "vibes")
    expect(p).not_to be_known
    expect(p.findings.first[:test]).to eq(:axes_known)
  end

  it "reads a placement out of OKF frontmatter" do
    p = described_class.from({ "layer" => "runtimes", "phase" => "extract",
                               "freezes_at_rung" => 3, "evidence" => "gold",
                               "instrument" => "operate" })
    expect(p.to_h).to eq(layer: "runtimes", phase: "extract", rung: 3,
                         evidence: "gold", instrument: "operate")
  end
end
