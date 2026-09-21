# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Adapters do
  describe described_class::Static do
    it "answers only the questions it was given and records the call" do
      adapter = described_class.new(route: { value: "fast_llm", confidence: 0.9 })
      answers = adapter.ask(state: { a: 1 }, questions: [route_question, refund_question])

      expect(answers.keys).to eq([:route])
      expect(answers[:route]).to include(value: "fast_llm", confidence: 0.9, source: "static")
      expect(adapter.calls.first[:questions]).to eq(%i[route refund_requested])
    end

    it "accepts a bare value" do
      adapter = described_class.new(route: "fast_llm")
      expect(adapter.ask(state: {}, questions: [route_question])[:route]).to include(value: "fast_llm")
    end
  end

  describe described_class::Unavailable do
    it "refuses with a named reason" do
      result = described_class.new.ask(state: { a: 1 }, questions: [route_question])
      expect(result[:ok]).to be(false)
      expect(result[:reason]).to eq(:provider_unavailable)
      expect(result[:questions]).to eq([:route])
    end
  end

  describe described_class::Chain do
    it "falls through a refusal to the next adapter" do
      chain = described_class.new(
        Vv::DecisionObject::Adapters::Unavailable.new,
        Vv::DecisionObject::Adapters::Static.new({ route: "fast_llm" }, source: "fallback")
      )
      answers = chain.ask(state: {}, questions: [route_question])
      expect(answers[:route]).to include(source: "fallback")
    end

    it "stops at the first adapter that answers" do
      second = Vv::DecisionObject::Adapters::Static.new({ route: "reasoning_llm" }, source: "second")
      chain = described_class.new(
        Vv::DecisionObject::Adapters::Static.new({ route: "fast_llm" }, source: "first"),
        second
      )
      expect(chain.ask(state: {}, questions: [route_question])[:route]).to include(source: "first")
      expect(second.calls).to be_empty
    end

    it "treats a raising adapter as a refusal and keeps going" do
      exploding = Class.new do
        def ask(state:, questions:) = raise("boom")
      end.new
      chain = described_class.new(exploding, Vv::DecisionObject::Adapters::Static.new(route: "fast_llm"))
      expect(chain.ask(state: {}, questions: [route_question])[:route]).to include(value: "fast_llm")
    end

    it "returns the last refusal when nothing answers" do
      chain = described_class.new(Vv::DecisionObject::Adapters::Unavailable.new)
      expect(chain.ask(state: {}, questions: [route_question])[:ok]).to be(false)
    end

    it "refuses an empty chain" do
      expect(described_class.new.ask(state: {}, questions: [])[:reason]).to eq(:no_adapters)
    end
  end

  describe described_class::Jev do
    it "maps a Jev-shaped response across all three primitives" do
      raw = {
        "route" => { "choice" => "fast_llm", "probabilities" => { "fast_llm" => 0.9, "human_review" => 0.1 },
                     "confidence" => 0.88 },
        "severity" => { "score" => 2.4, "levels" => { "high" => 0.7 }, "confidence" => 0.7 },
        "refund_requested" => { "probability" => 0.93 }
      }

      mapped = described_class.map(raw, model: "jev-1.13.0")

      expect(mapped[:route]).to include(value: "fast_llm", confidence: 0.88, source: "jev-1.13.0")
      expect(mapped[:severity][:value]).to eq(2.4)
      expect(mapped[:severity][:probabilities]).to eq("high" => 0.7)
      expect(mapped[:refund_requested][:value]).to eq(0.93)
    end

    it "lets a per-answer model id win over the default" do
      mapped = described_class.map({ "route" => { "choice" => "fast_llm", "model" => "jev-1.14.0" } },
                                   model: "jev-1.13.0")
      expect(mapped[:route][:source]).to eq("jev-1.14.0")
    end

    it "wraps a callable into an adapter and drives a real decision" do
      adapter = described_class.adapter(model: "jev-1.13.0") do |state, questions|
        expect(state[:tier]).to eq("premium")
        questions.each_with_object({}) do |q, out|
          out[q.name.to_s] = case q.kind
                             when :choice then { "choice" => "fast_llm", "confidence" => 0.95 }
                             else { "probability" => 0.9, "confidence" => 0.9 }
                             end
        end
      end

      decision = triage_definition.instantiate(state: clean_state)[:data]
      expect(decision.evaluate(adapter)[:data][:disposition]).to eq(:commit)
      expect(decision.answer(:route).source).to eq("jev-1.13.0")
    end

    it "refuses an adapter built with no block" do
      expect(described_class::Callable.new.ask(state: {}, questions: [])[:reason]).to eq(:no_block)
    end

    it "passes a non-hash response through untouched" do
      expect(described_class.map("nope")).to eq("nope")
    end
  end
end
