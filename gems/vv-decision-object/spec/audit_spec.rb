# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Audit do
  def decided(definition, state: clean_state, adapter: confident_adapter, outcome: nil)
    decision = definition.instantiate(state: state)[:data]
    decision.evaluate(adapter)
    decision.commit!(handler: "billing") if decision.disposition == :commit
    decision.record_outcome(**outcome) if outcome
    decision
  end

  def modes(result)
    result[:data][:findings].map { |f| f[:mode] }
  end

  it "refuses an empty set" do
    expect(described_class.run([])[:reason]).to eq(:no_decisions)
  end

  it "refuses a set spanning different definitions" do
    other = Vv::DecisionObject.define(:other) do |d|
      d.intent "Something else"
      d.ask refund_question
    end[:data]

    set = [decided(triage_definition), decided(other, adapter: confident_adapter)]
    expect(described_class.run(set)[:reason]).to eq(:mixed_definitions)
  end

  it "finds nothing wrong with a healthy set" do
    definition = triage_definition
    healthy = Array.new(18) { decided(definition, outcome: { resolved: true, reopened: false }) }
    healthy += Array.new(2) { decided(definition, adapter: confident_adapter(confidence: 0.3)) }

    result = described_class.run(healthy)
    expect(result[:ok]).to be(true)
    expect(modes(result)).to be_empty
    expect(result[:underpowered]).to be(false)
  end

  it "flags an underpowered set without refusing it" do
    definition = triage_definition
    set = [decided(definition, outcome: { resolved: true, reopened: false }),
           decided(definition, adapter: confident_adapter(confidence: 0.3))]
    expect(described_class.run(set)[:underpowered]).to be(true)
  end

  describe "over-automation" do
    it "flags a set where the floor never bound" do
      definition = triage_definition
      set = Array.new(20) { decided(definition, outcome: { resolved: true, reopened: false }) }
      result = described_class.run(set)

      expect(modes(result)).to include(:over_automation)
      finding = result[:data][:findings].find { |f| f[:mode] == :over_automation }
      expect(finding[:because]).to include("0.0% of decisions escalated")
      expect(finding[:evidence][:floors]).to eq(route: 0.8, refund_requested: 0.0)
    end
  end

  describe "feedback suppression" do
    it "flags commitments with no recorded outcome" do
      definition = triage_definition
      set = Array.new(8) { decided(definition, outcome: { resolved: true, reopened: false }) }
      set += Array.new(12) { decided(definition) }

      finding = described_class.run(set)[:data][:findings].find { |f| f[:mode] == :feedback_suppression }
      expect(finding[:because]).to include("40.0%")
      expect(finding[:evidence]).to include(committed: 20, with_outcome: 8)
    end

    it "does not flag a set that meets the feedback floor exactly" do
      definition = triage_definition
      set = Array.new(10) { decided(definition, outcome: { resolved: true, reopened: false }) }
      set += Array.new(10) { decided(definition) }

      expect(modes(described_class.run(set))).not_to include(:feedback_suppression)
    end

    it "flags a definition with no feedback layer at all" do
      definition = Vv::DecisionObject.define(:no_feedback) do |d|
        d.intent "Decide"
        d.signal :subject, :body, :tier, :contains_pii
        d.ask route_question
        d.thresholds floors: { route: 0.0 }
        d.commit_to :do_it
      end[:data]

      set = [decided(definition, adapter: confident_adapter)]
      finding = described_class.run(set)[:data][:findings].find { |f| f[:mode] == :feedback_suppression }
      expect(finding[:because]).to include("declares no feedback layer")
    end
  end

  describe "signal degradation" do
    it "flags decisions that ran without a declared signal" do
      definition = triage_definition
      set = Array.new(10) { decided(definition, outcome: { resolved: true, reopened: false }) }
      set += Array.new(10) do
        decided(definition, state: { subject: "s", body: "b", contains_pii: false },
                            outcome: { resolved: true, reopened: false })
      end

      finding = described_class.run(set)[:data][:findings].find { |f| f[:mode] == :signal_degradation }
      expect(finding[:because]).to include("50.0%")
      expect(finding[:evidence][:missing]).to eq(tier: 10)
    end
  end

  describe "constraint drift" do
    it "flags a set spanning definition versions" do
      set = Array.new(10) { decided(triage_definition(version: 1), outcome: { resolved: true, reopened: false }) }
      set += Array.new(10) { decided(triage_definition(version: 2), outcome: { resolved: true, reopened: false }) }

      finding = described_class.run(set)[:data][:findings].find { |f| f[:mode] == :constraint_drift }
      expect(finding[:evidence][:versions]).to eq(1 => 10, 2 => 10)
    end
  end

  describe "metric myopia" do
    it "flags an evaluation layer carried by one evaluator" do
      definition = Vv::DecisionObject.define(:single) do |d|
        d.intent "Decide"
        d.signal :body
        d.ask refund_question
        d.commit_to :do_it
        d.track :resolved
      end[:data]

      set = [decided(definition, state: { body: "refund please" },
                                 adapter: Vv::DecisionObject::Adapters::Static.new(refund_requested: 0.9),
                                 outcome: { resolved: true })]
      expect(modes(described_class.run(set))).to include(:metric_myopia)
    end

    it "does not flag a definition with more than one evaluator" do
      set = Array.new(20) { decided(triage_definition, outcome: { resolved: true, reopened: false }) }
      expect(modes(described_class.run(set))).not_to include(:metric_myopia)
    end
  end

  it "counts dispositions and outcomes" do
    definition = triage_definition
    set = Array.new(3) { decided(definition, outcome: { resolved: true, reopened: false }) }
    set << decided(definition, adapter: confident_adapter(confidence: 0.2))
    set << decided(definition, state: clean_state(pii: true))

    counts = described_class.run(set)[:data][:counts]
    expect(counts).to include(decisions: 5, committed: 3, escalated: 1, refused: 1,
                              committed_with_outcome: 3)
  end

  it "accepts threshold overrides" do
    definition = triage_definition
    set = Array.new(20) { decided(definition, outcome: { resolved: true, reopened: false }) }
    expect(modes(described_class.run(set, escalation_floor: -1.0))).not_to include(:over_automation)
  end
end
