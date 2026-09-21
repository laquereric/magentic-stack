# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Question do
  describe Vv::DecisionObject::Choice do
    it "declares its options and reports its kind" do
      q = route_question
      expect(q.kind).to eq(:choice)
      expect(q.options).to eq(%w[deterministic_code fast_llm reasoning_llm human_review])
      expect(q).to be_valid
    end

    it "admits only declared options" do
      q = route_question
      expect(q.admits?("fast_llm")).to be(true)
      expect(q.admits?(:fast_llm)).to be(true)
      expect(q.admits?("gpt_please")).to be(false)
    end

    it "finds the escape route" do
      expect(route_question.escape).to eq("human_review")
      expect(route_question).to be_escape
    end

    it "refuses a closed set with no way out" do
      q = described_class.new(:tier, instructions: "Which tier?",
                                     criteria: { gold: "big", silver: "small" })
      expect(q).not_to be_valid
      expect(q.problems.join).to include("no escape option")
    end

    it "needs at least two options and criteria for each" do
      q = described_class.new(:only, instructions: "?", criteria: { unknown: "" })
      expect(q.problems).to include(a_string_including("at least two options"))
      expect(q.problems).to include(a_string_including("option unknown has no criteria"))
    end

    it "needs instructions" do
      q = described_class.new(:route, instructions: "", criteria: { a: "x", unknown: "y" })
      expect(q.problems).to include(a_string_including("instructions are required"))
    end
  end

  describe Vv::DecisionObject::Score do
    it "orders levels as declared and maps scores onto them" do
      q = severity_question
      expect(q.levels).to eq(%w[low medium high critical])
      expect(q.range).to eq(0..3)
      expect(q.level_at(0)).to eq("low")
      expect(q.level_at(2.4)).to eq("high")
      expect(q.level_at(99)).to eq("critical")
    end

    it "normalizes onto 0.0..1.0" do
      q = severity_question
      expect(q.normalize(0)).to eq(0.0)
      expect(q.normalize(3)).to eq(1.0)
      expect(q.normalize(1.5)).to eq(0.5)
    end

    it "admits only numbers inside the rubric range" do
      q = severity_question
      expect(q.admits?(2)).to be(true)
      expect(q.admits?(3.5)).to be(false)
      expect(q.admits?("high")).to be(false)
    end
  end

  describe Vv::DecisionObject::Noul do
    it "admits only a probability" do
      q = refund_question
      expect(q.kind).to eq(:noul)
      expect(q.admits?(0.0)).to be(true)
      expect(q.admits?(1.0)).to be(true)
      expect(q.admits?(1.4)).to be(false)
      expect(q.admits?("yes")).to be(false)
    end
  end
end
