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

  it "names an axis value outside its closed set rather than guessing" do
    p = place(instrument: "vibes")
    expect(p).not_to be_known
    expect(p.findings.first[:test]).to eq(:axes_known)
  end

  it "reads a placement out of OKF frontmatter" do
    p = described_class.from("layer" => "runtimes", "phase" => "extract",
                             "freezes_at_rung" => 3, "evidence" => "gold",
                             "instrument" => "operate")
    expect(p.to_h).to eq(layer: "runtimes", phase: "extract", rung: 3,
                         evidence: "gold", instrument: "operate")
  end
end
