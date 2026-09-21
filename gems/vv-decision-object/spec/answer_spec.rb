# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Answer do
  def answer_for(question, **kwargs)
    described_class.new(question: question, **kwargs)
  end

  it "reports the margin between the top two candidates" do
    a = answer_for(route_question, value: "fast_llm",
                                   probabilities: { "fast_llm" => 0.52, "reasoning_llm" => 0.44, "human_review" => 0.04 })
    expect(a.margin).to be_within(0.001).of(0.08)
  end

  it "has no margin when only one candidate has mass" do
    a = answer_for(route_question, value: "fast_llm", probabilities: { "fast_llm" => 1.0 })
    expect(a.margin).to be_nil
  end

  it "derives confidence from distribution shape when none is reported" do
    close = answer_for(route_question, value: "fast_llm",
                                       probabilities: { "fast_llm" => 0.51, "reasoning_llm" => 0.49 })
    clear = answer_for(route_question, value: "fast_llm",
                                       probabilities: { "fast_llm" => 0.97, "reasoning_llm" => 0.03 })

    expect(close.confidence).to be < clear.confidence
    expect(close.confidence).to be_within(0.001).of(0.265)
  end

  it "prefers a reported confidence over a derived one" do
    a = answer_for(route_question, value: "fast_llm", confidence: 0.8,
                                   probabilities: { "fast_llm" => 0.51, "reasoning_llm" => 0.49 })
    expect(a.confidence).to eq(0.8)
  end

  it "is zero-confidence with no distribution at all" do
    expect(answer_for(route_question, value: "fast_llm").confidence).to eq(0.0)
  end

  it "knows when the value falls outside the declared space" do
    expect(answer_for(route_question, value: "fast_llm")).to be_admissible
    expect(answer_for(route_question, value: "sonnet")).not_to be_admissible
  end

  it "knows when the model took the escape route itself" do
    expect(answer_for(route_question, value: "human_review")).to be_escaped
    expect(answer_for(route_question, value: "fast_llm")).not_to be_escaped
  end

  it "resolves a score to its rubric level and normal form" do
    a = answer_for(severity_question, value: 2.6, confidence: 0.7)
    expect(a.level).to eq("critical")
    expect(a.normalized).to be_within(0.001).of(0.867)
  end

  it "thresholds a noul at a declared cut" do
    a = answer_for(refund_question, value: 0.62)
    expect(a.true?).to be(true)
    expect(a.true?(at: 0.8)).to be(false)
  end

  it "leaves level and normalized nil for non-scores" do
    a = answer_for(route_question, value: "fast_llm")
    expect(a.level).to be_nil
    expect(a.normalized).to be_nil
    expect(a.true?).to be(false)
  end
end
