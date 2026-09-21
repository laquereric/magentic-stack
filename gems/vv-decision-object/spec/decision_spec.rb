# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Decision do
  def run(state: clean_state, definition: triage_definition, actor: "agent:triage")
    definition.instantiate(state: state, actor: actor)[:data]
  end

  describe "the happy path" do
    it "checks constraints, answers, disposes, commits and closes the loop" do
      decision = run
      result = decision.evaluate(confident_adapter)

      expect(result[:ok]).to be(true)
      expect(result[:data][:disposition]).to eq(:commit)
      expect(decision.lifecycle).to eq(:executed)
      expect(decision.answer(:route).value).to eq("fast_llm")
      expect(decision.answer(:refund_requested).true?).to be(true)

      expect(decision.commit!(handler: "billing")[:ok]).to be(true)
      expect(decision).to be_committed

      outcome = decision.record_outcome(resolved: true, reopened: false)
      expect(outcome[:ok]).to be(true)
      expect(decision.lifecycle).to eq(:monitored)
    end

    it "traces every step in order" do
      decision = run
      decision.evaluate(confident_adapter)
      decision.commit!(handler: "billing")
      decision.record_outcome(resolved: true, reopened: false)

      expect(decision.trace.to_a.map { |e| e[:kind] }).to eq(
        %i[instantiated answered answered disposition committed outcome_recorded]
      )
    end
  end

  describe "constraints first" do
    it "refuses without ever consulting the adapter" do
      adapter = confident_adapter
      decision = run(state: clean_state(pii: true))
      result = decision.evaluate(adapter)

      expect(result[:data][:disposition]).to eq(:refuse)
      expect(result[:data][:blocking]).to eq([:no_pii_to_vendor])
      expect(adapter.calls).to be_empty
      expect(decision.answers).to be_empty
    end

    it "records the violation in the trace" do
      decision = run(state: clean_state(pii: true))
      decision.evaluate(confident_adapter)
      violation = decision.trace.last_of(:constraint_violated)
      expect(violation.payload).to include(constraint: :no_pii_to_vendor, hard: true)
    end
  end

  describe "thresholds" do
    it "escalates rather than committing when confidence is short" do
      decision = run
      result = decision.evaluate(confident_adapter(confidence: 0.4))
      expect(result[:data][:disposition]).to eq(:escalate)
      expect(decision.commit!(handler: "billing")[:reason]).to eq(:not_committable)
      expect(decision).not_to be_committed
    end

    it "applies the stricter per-option floor to the option that won" do
      decision = run
      result = decision.evaluate(confident_adapter(route: "deterministic_code", confidence: 0.88))
      expect(result[:data][:disposition]).to eq(:escalate)
      expect(result[:data][:because]).to include("below floor 0.90")
    end

    it "abstains on an answer outside the declared option set" do
      decision = run
      result = decision.evaluate(confident_adapter(route: "sonnet"))
      expect(result[:data][:disposition]).to eq(:abstain)
    end
  end

  describe "adapter failure" do
    it "returns the adapter's refusal and traces it" do
      decision = run
      result = decision.evaluate(Vv::DecisionObject::Adapters::Unavailable.new)

      expect(result[:ok]).to be(false)
      expect(result[:reason]).to eq(:provider_unavailable)
      expect(decision.trace.last_of(:adapter_failed).payload[:reason]).to eq(:provider_unavailable)
    end

    it "refuses instead of raising when an adapter blows up" do
      exploding = Class.new do
        def ask(state:, questions:) = raise(IOError, "socket closed")
      end.new

      result = run.evaluate(exploding)
      expect(result[:reason]).to eq(:adapter_error)
      expect(result[:because]).to include("IOError: socket closed")
    end

    it "refuses when an adapter skips a declared question" do
      partial = Vv::DecisionObject::Adapters::Static.new(route: { value: "fast_llm", confidence: 0.9 })
      result = run.evaluate(partial)
      expect(result[:reason]).to eq(:answer_missing)
      expect(result[:question]).to eq(:refund_requested)
    end

    it "refuses a malformed adapter return" do
      junk = Class.new do
        def ask(state:, questions:) = "sure, route it to billing"
      end.new
      expect(run.evaluate(junk)[:reason]).to eq(:adapter_malformed)
    end

    it "refuses when questions are declared but no adapter is supplied" do
      expect(run.evaluate[:reason]).to eq(:adapter_required)
    end
  end

  describe "guards" do
    it "evaluates only once" do
      decision = run
      decision.evaluate(confident_adapter)
      expect(decision.evaluate(confident_adapter)[:reason]).to eq(:already_evaluated)
    end

    it "will not commit twice" do
      decision = run
      decision.evaluate(confident_adapter)
      decision.commit!(handler: "billing")
      expect(decision.commit!(handler: "billing")[:reason]).to eq(:already_committed)
    end

    it "will not commit or record an outcome before evaluation" do
      decision = run
      expect(decision.commit!(handler: "x")[:reason]).to eq(:not_evaluated)
      expect(decision.record_outcome(resolved: true)[:reason]).to eq(:not_evaluated)
    end

    it "refuses an outcome the feedback layer never declared" do
      decision = run
      decision.evaluate(confident_adapter)
      result = decision.record_outcome(resolved: true, vibes: "good")
      expect(result[:reason]).to eq(:undeclared_feedback)
      expect(result[:undeclared]).to eq([:vibes])
    end

    it "accepts a partial outcome but names what is still missing" do
      decision = run
      decision.evaluate(confident_adapter)
      result = decision.record_outcome(resolved: true)
      expect(result[:ok]).to be(true)
      expect(result[:missing]).to eq([:reopened])
    end
  end

  describe "decision tables" do
    it "evaluates the deterministic layer alongside the semantic one" do
      definition = Vv::DecisionObject.define(:refund) do |d|
        d.intent "Decide who may approve this refund"
        d.signal :amount, :tier
        d.decision_table(:authority, inputs: %i[amount tier], outputs: %i[approver],
                                     rules: [
                                       { when: { amount: ->(v) { v < 50 } }, then: { approver: "auto" } },
                                       { when: { amount: :any, tier: :any }, then: { approver: "manager" } }
                                     ])
        d.commit_to :assign_approver
        d.track :approved
        d.constraint(:positive, because: "refunds are positive") { |s| s[:amount].to_f.positive? }
      end[:data]

      decision = definition.instantiate(state: { amount: 20, tier: "basic" })[:data]
      result = decision.evaluate

      expect(result[:data][:disposition]).to eq(:commit)
      expect(decision.table_results[:authority][:data]).to eq(approver: "auto")
      expect(decision.trace.last_of(:table_evaluated).payload[:outputs]).to eq(approver: "auto")
    end
  end

  describe "lifecycle" do
    it "advances through audit and revision" do
      decision = run
      decision.evaluate(confident_adapter)
      decision.commit!(handler: "billing")
      decision.record_outcome(resolved: true, reopened: false)

      expect(decision.transition(:audited)[:ok]).to be(true)
      expect(decision.transition(:revised)[:ok]).to be(true)
      expect(decision.lifecycle).to eq(:revised)
    end

    it "refuses an illegal jump and leaves the state alone" do
      decision = run
      expect(decision.transition(:audited)[:reason]).to eq(:illegal_transition)
      expect(decision.lifecycle).to eq(:instantiated)
    end
  end

  describe "serialization" do
    it "renders the whole object as a hash and as an ADR" do
      decision = run
      decision.evaluate(confident_adapter)
      decision.commit!(handler: "billing")

      h = decision.to_h
      expect(h[:definition]).to eq(:route_ticket)
      expect(h[:actor]).to eq("agent:triage")
      expect(h[:disposition]).to eq(:commit)
      expect(h[:answers][:route][:value]).to eq("fast_llm")
      expect(h[:trace].size).to eq(5)

      expect(JSON.parse(decision.to_json)["id"]).to eq(decision.id)
      expect(decision.to_markdown).to include("# route_ticket — #{decision.id}")
    end
  end
end
