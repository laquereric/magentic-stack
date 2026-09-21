# frozen_string_literal: true

RSpec.describe Vv::DecisionObject do
  it "has a version" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "names the six layers in evaluation order" do
    expect(described_class::LAYERS).to eq(%i[intent constraint signal evaluation commitment feedback])
  end

  it "names the five failure modes" do
    expect(described_class::FAILURE_MODES.size).to eq(5)
    expect(described_class::FAILURE_MODES).to include(:constraint_drift, :over_automation)
  end

  it "exposes the question primitives at the top level" do
    expect(described_class::Choice).to be(Vv::DecisionObject::Question::Choice)
    expect(described_class::Score).to be(Vv::DecisionObject::Question::Score)
    expect(described_class::Noul).to be(Vv::DecisionObject::Question::Noul)
  end

  describe ".define" do
    it "returns a definition in an envelope" do
      result = described_class.define(:x) do |d|
        d.intent "Decide"
        d.ask refund_question
      end
      expect(result[:ok]).to be(true)
      expect(result[:data]).to be_a(described_class::Definition)
    end
  end

  describe ".open" do
    it "defines and instantiates in one call" do
      result = described_class.open(:x, state: { body: "refund please" }) do |d|
        d.intent "Decide whether a refund was asked for"
        d.signal :body
        d.ask refund_question
        d.commit_to :flag_refund
        d.track :resolved
      end

      expect(result[:ok]).to be(true)
      expect(result[:data]).to be_a(described_class::Decision)
    end

    it "passes a definition refusal straight through" do
      expect(described_class.open(:x)[:reason]).to eq(:definition_invalid)
    end
  end

  describe ".audit" do
    it "delegates to Audit" do
      expect(described_class.audit([])[:reason]).to eq(:no_decisions)
    end
  end

  describe "the README walkthrough" do
    it "runs end to end" do
      definition = described_class.define(:route_support_ticket) do |d|
        d.intent "Route the ticket to the handler that can close it",
                 tradeoffs: ["speed over precision below $500 exposure"]
        d.constraint(:no_pii_to_vendor, because: "DPA forbids vendor PII") { |s| !s[:contains_pii] }
        d.signal :subject, :body, :tier, :contains_pii
        d.choice(:route, instructions: "Which handler should process this ticket?",
                         criteria: {
                           deterministic_code: "A fixed lookup or rule is sufficient",
                           fast_llm: "Short generation, limited reasoning",
                           reasoning_llm: "Multi-step interpretation is required",
                           human_review: "Ambiguous, sensitive, or outside the routes"
                         })
        d.noul(:refund_requested, instructions: "Does the body request a refund?")
        d.thresholds floors: { route: 0.80 }, margin_floor: 0.15, on_uncertain: :escalate
        d.commit_to :assign_handler
        d.track :resolved, :reopened
      end[:data]

      decision = definition.instantiate(
        state: { subject: "Charged twice", body: "Please refund me", tier: "premium", contains_pii: false },
        actor: "agent:triage-1"
      )[:data]

      adapter = described_class::Adapters::Static.new(
        route: { value: "fast_llm", confidence: 0.91,
                 probabilities: { "fast_llm" => 0.91, "reasoning_llm" => 0.06, "human_review" => 0.03 } },
        refund_requested: { value: 0.97, confidence: 0.94 }
      )

      result = decision.evaluate(adapter)
      expect(result[:data][:disposition]).to eq(:commit)

      decision.commit!(handler: "billing")
      decision.record_outcome(resolved: true, reopened: false)

      expect(decision.lifecycle).to eq(:monitored)
      expect(decision.to_h[:trace].size).to eq(6)
    end
  end
end
