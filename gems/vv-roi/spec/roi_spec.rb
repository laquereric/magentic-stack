# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Roi do
  describe "build" do
    it "names every problem at once rather than the first" do
      out = described_class::Stakes.build(question: "route", options: {})
      expect(out[:ok]).to be false
      expect(out[:reason]).to eq :stakes_invalid
      expect(out[:problems].map { |p| p[:key] }).to include(:question, :options)
    end

    it "refuses an escape option it cannot price" do
      out = described_class::Stakes.build(question: :route, escape: :nowhere,
                                          options: { a: { gain: 1, loss: 1 } })
      expect(out[:ok]).to be false
    end
  end

  describe "appraisal" do
    it "prefers the valuable option over the likely one and says so" do
      a = appraise({ fast_llm: 0.55, deterministic_code: 0.45 })[:data]
      expect(a.likeliest).to eq :fast_llm
      expect(a.best).to eq :deterministic_code
      expect(a.diverges?).to be true
      expect(a.verdict).to eq :vetoes
      expect(a.reason).to eq :value_divergence
    end

    it "vetoes when holding is worth more than the best action" do
      a = appraise({ fast_llm: 0.72, human_review: 0.28 })[:data]
      expect(a.net_option_value).to be < 0
      expect(a.reason).to eq :negative_expected_value
    end

    it "clears when the answer is both likely and valuable" do
      a = appraise({ deterministic_code: 0.95, fast_llm: 0.05 })[:data]
      expect(a.best).to eq :deterministic_code
      expect(a.clears?).to be true
      expect(a.net_option_value).to be > 0
    end

    it "prices holding, not just acting" do
      a = appraise({ deterministic_code: 0.55, fast_llm: 0.45 })[:data]
      expect(a.hold).to be < 0            # review costs money
      expect(a.net_option_value).to eq(a.expected_value[a.best] - a.hold)
    end

    it "labels a bounded upside against a long tail as concave" do
      a = appraise({ fast_llm: 0.99, human_review: 0.01 })[:data]
      expect(a.best).to eq :fast_llm
      expect(a.clears?).to be true     # the expected value looks fine
      expect(a.shape).to eq :concave   # and the tail is still 260x the upside
    end

    it "treats an unevaluable payoff as the bad case, not an exception" do
      s = stakes(options: {
                   deterministic_code: { gain: ->(_) { raise "boom" }, loss: 12.00 },
                   human_review: { gain: 0.00, loss: 0.00, cost: 9.00 }
                 }, versus: {})
      out = appraise({ deterministic_code: 1.0 }, s: s)
      expect(out[:ok]).to be false
      expect(out[:reason]).to eq :stakes_error
    end
  end

  describe "risk appetite" do
    it "vetoes on worst case regardless of expected value" do
      a = appraise({ fast_llm: 0.995, human_review: 0.005 },
                   p: policy(allow_cost_sensitive_selection: true,
                             plausible_above: 0.001,
                             worst_case_floor: -250.00))[:data]
      expect(a.verdict).to eq :vetoes
      expect(a.reason).to eq :downside_exceeded
    end

    it "will not let expected value argue past ruin" do
      dist = { execute: 0.995, human_review: 0.005 }
      expect(appraise(dist, s: trade_stakes).fetch(:data).clears?).to be true

      a = appraise(dist, s: trade_stakes, p: policy(ruin_below: -5_000.00))[:data]
      expect(a.verdict).to eq :vetoes
      expect(a.reason).to eq :ruin_risk
      expect(a.because).to include("unrecoverable branch")
    end

    it "reserves one-way doors for humans when asked to" do
      s = stakes(options: {
                   deterministic_code: { gain: 2.00, loss: 12.00, reversible: false },
                   human_review: { gain: 0.00, loss: 0.00, cost: 9.00 }
                 }, versus: {})
      a = appraise({ deterministic_code: 0.99, human_review: 0.01 },
                   s: s, p: policy(irreversible_requires_human: true))[:data]
      expect(a.reason).to eq :irreversible_commitment
    end
  end

  describe "the gate" do
    it "downgrades a commit it vetoes" do
      a = appraise({ fast_llm: 0.72, human_review: 0.28 })[:data]
      out = described_class.gate(:commit, a)
      expect(out[:data][:disposition]).to eq :escalate
    end

    it "never upgrades an escalation, however good the numbers look" do
      a = appraise({ deterministic_code: 0.99, fast_llm: 0.01 })[:data]
      expect(a.clears?).to be true
      out = described_class.gate(:escalate, a)
      expect(out[:data][:disposition]).to eq :escalate
    end

    it "leaves a refusal alone" do
      a = appraise({ deterministic_code: 0.99, fast_llm: 0.01 })[:data]
      expect(described_class.gate(:refuse, a)[:data][:disposition]).to eq :refuse
    end
  end

  describe "feedback" do
    it "prices the outcomes the feedback layer already tracks" do
      out = described_class.realize({ resolved: true, reopened: false },
                                    valuation: { resolved: { true => 2.00, false => -15.00 },
                                                 reopened: { true => -8.00 } })
      expect(out[:data][:realized]).to eq 2.00
    end
  end

  describe "audit" do
    let(:priced) do
      Array.new(60) do
        { disposition: :commit, expected: 1.80, realized: 0.40,
          worst_case: -250.00, hold: -9.00, expected_loss: -1.20,
          shape: :linear, reversible: true }
      end
    end

    it "reports underpowered rather than trusting a small set" do
      out = described_class.audit(priced.first(5))
      expect(out[:underpowered]).to be true
    end

    it "catches a payoff table that reality disagrees with" do
      out = described_class.audit(priced)
      expect(out[:data][:findings].map { |f| f[:mode] }).to include(:payoff_drift)
    end

    it "catches a floor set too high, not only one set too low" do
      escalated = Array.new(60) do
        { disposition: :escalate, expected: 1.80, hold: -9.00, expected_loss: -0.20 }
      end
      out = described_class.audit(escalated)
      expect(out[:data][:findings].map { |f| f[:mode] }).to include(:escalation_waste)
    end
  end

  describe "portfolio" do
    it "counts the options the system has sold" do
      out = described_class.portfolio([
                                        { disposition: :commit, reversible: false, worst_case: -250.0,
                                          shape: :concave, expected: 1.0 },
                                        { disposition: :commit, reversible: true, worst_case: -12.0,
                                          shape: :linear, expected: 1.0 }
                                      ])
      expect(out[:data][:short_option_position]).to eq 1
      expect(out[:data][:shape_mix]).to eq({ concave: 1, linear: 1 })
    end
  end
end
