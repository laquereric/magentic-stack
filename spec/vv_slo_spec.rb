# frozen_string_literal: true
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "vv-slo"

RSpec.describe Vv::Slo do
  describe Vv::Slo::Objective do
    let(:slo) do
      described_class.new(service: "checkout-api", target: 0.999, time_window: "30d",
                          good_query: 'sum(http_requests_total{code=~"2..|3.."})',
                          total_query: "sum(http_requests_total)")
    end

    it "computes the error budget and the minutes it buys" do
      r = slo.validate
      expect(r[:ok]).to eq(true)
      expect(r[:errorBudget]).to be_within(1e-9).of(0.001)
      expect(r[:budgetMinutes]).to eq(43.2) # ~43 minutes over 30 days
    end

    it "REFUSES an SLO no machine can query -- the whole point" do
      r = described_class.new(service: "checkout-api", target: 0.999).validate
      expect(r[:ok]).to eq(false)
      expect(r[:reason]).to eq(:unqueryable)
    end

    it "refuses a target that is not a ratio" do
      r = described_class.new(service: "x", target: 99.9, good_query: "a", total_query: "b").validate
      expect(r[:reason]).to eq(:target_invalid)
    end

    it "emits an OpenSLO-shaped manifest" do
      expect(slo.to_openslo.dig("spec", "objectives", 0, "target")).to eq(0.999)
    end
  end

  describe Vv::Slo::BurnRate do
    it "pages when a tier's OWN two windows both exceed its factor" do
      r = described_class.classify("1h" => 20.0, "5m" => 18.0)
      expect(r[:name]).to eq(:page)
      expect(r[:fired]).to eq(true)
    end

    it "does NOT page when only the long window is hot -- the pairing is the filter" do
      # a spike that has already subsided: 1h is high, 5m is not
      expect(described_class.classify("1h" => 20.0, "5m" => 1.0)[:name]).to eq(:none)
    end

    it "cannot fire a tier whose windows are absent" do
      # 1h/5m present but far below 14.4; the 6h and 3d tiers have no data at all
      expect(described_class.classify("1h" => 2.0, "5m" => 2.0)[:name]).to eq(:none)
    end

    it "drops to a ticket for slow drift over its own windows" do
      expect(described_class.classify("3d" => 1.5, "6h" => 1.2)[:name]).to eq(:ticket)
    end

    it "computes burn as observed over allowed" do
      expect(described_class.burn(observed_error_rate: 0.014, error_budget: 0.001)).to eq(14.0)
    end
  end

  describe Vv::Slo::BudgetGate do
    it "lets an agent ship autonomously on a healthy budget" do
      r = described_class.evaluate(remaining: 0.80, actor: :agent)
      expect(r[:agentChanges]).to eq(:autonomous)
      expect(r[:allowedWithoutReview]).to eq(true)
    end

    it "requires human review of MACHINE changes as soon as the budget is dented" do
      r = described_class.evaluate(remaining: 0.30, actor: :agent)
      expect(r[:agentChanges]).to eq(:human_review)
      expect(r[:allowedWithoutReview]).to eq(false)
    end

    it "still permits a human deploy at a level where an agent is gated" do
      expect(described_class.evaluate(remaining: 0.30, actor: :human)[:allowedWithoutReview]).to eq(true)
    end

    it "blocks agents entirely at an exhausted budget" do
      r = described_class.evaluate(remaining: 0.0, actor: :agent)
      expect(r[:deploy]).to eq(:freeze)
      expect(r[:agentChanges]).to eq(:blocked)
    end
  end

  describe Vv::Slo::ObservabilityContract do
    let(:c) do
      described_class.new(service: "checkout-api", environment: "production", owner: "payments",
                          required_attributes: %w[trace_id span_id],
                          cardinality_limits: { "user_id" => 100 })
    end

    it "refuses telemetry with no owner -- useless at 3:12 AM" do
      r = described_class.new(service: "x", environment: "production", owner: "").validate
      expect(r[:ok]).to eq(false)
      expect(r[:because]).to include("owner")
    end

    it "filters forbidden attributes rather than recommending against them" do
      r = c.check_signal(name: "http.server.request", attributes: { "authorization" => "Bearer x" })
      expect(r[:reason]).to eq(:forbidden_attribute)
    end

    it "requires cross-signal correlation ids" do
      r = c.check_signal(name: "log", attributes: { "trace_id" => "abc" })
      expect(r[:reason]).to eq(:required_attribute_missing)
      expect(r[:because]).to eq(["span_id"])
    end

    it "catches cardinality explosion, which is a COST failure" do
      r = c.check_signal(name: "m", attributes: { "trace_id" => "a", "span_id" => "b" },
                         cardinality: { "user_id" => 5_000 })
      expect(r[:reason]).to eq(:cardinality_exceeded)
    end

    it "enforces at BOTH build and runtime" do
      expect(c.validate[:enforcementPoints]).to eq(%i[build runtime])
    end
  end

  describe Vv::Slo::Runbook do
    it "does NOT gate an irreversible act with a negligible blast radius" do
      # restarting a stateless pod
      r = described_class.hitl_required?(irreversible: true, blast_radius: :negligible)
      expect(r[:hitlRequired]).to eq(false)
    end

    it "GATES an irreversible act with a large blast radius" do
      # dropping a production index
      r = described_class.hitl_required?(irreversible: true, blast_radius: :organization)
      expect(r[:hitlRequired]).to eq(true)
    end

    it "does not gate a reversible act however large" do
      expect(described_class.hitl_required?(irreversible: false, blast_radius: :organization)[:hitlRequired]).to eq(false)
    end

    it "takes NO confidence argument at all -- the rule is consequence, not certainty" do
      params = described_class.method(:hitl_required?).parameters.map(&:last)
      expect(params).to eq(%i[irreversible blast_radius])
      expect(params).not_to include(:confidence)
    end

    it "knows a prose runbook cannot be rehearsed" do
      expect(described_class.new(name: "restart", rung: 1).rehearsable?).to eq(false)
      expect(described_class.new(name: "restart", rung: 3).rehearsable?).to eq(true)
    end
  end
end
