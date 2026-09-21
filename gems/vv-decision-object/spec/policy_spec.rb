# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Policy do
  def answers(route_value: "fast_llm", route_confidence: 0.9, probabilities: nil)
    a = Vv::DecisionObject::Answer.new(
      question: route_question,
      value: route_value,
      confidence: route_confidence,
      probabilities: probabilities || { route_value => route_confidence }
    )
    { route: a }
  end

  it "commits when every floor is cleared" do
    policy = described_class.new(floors: { route: 0.8 })
    result = policy.apply(answers(route_confidence: 0.91))
    expect(result[:disposition]).to eq(:commit)
  end

  it "escalates below the per-question floor" do
    policy = described_class.new(floors: { route: 0.8 })
    result = policy.apply(answers(route_confidence: 0.62))
    expect(result[:disposition]).to eq(:escalate)
    expect(result[:because]).to include("confidence 0.62 below floor 0.80")
    expect(result[:blocking]).to eq([:route])
  end

  it "calibrates by consequence: a per-option floor beats the question floor" do
    policy = described_class.new(
      floors: { route: 0.50 },
      option_floors: { route: { deterministic_code: 0.95, human_review: 0.0 } }
    )
    expect(policy.apply(answers(route_value: "deterministic_code", route_confidence: 0.8))[:disposition]).to eq(:escalate)
    expect(policy.apply(answers(route_value: "fast_llm", route_confidence: 0.8))[:disposition]).to eq(:commit)
  end

  it "escalates a coin flip even when the winner looks confident enough" do
    policy = described_class.new(floors: { route: 0.5 }, margin_floor: 0.2)
    result = policy.apply(answers(route_confidence: 0.52,
                                  probabilities: { "fast_llm" => 0.52, "reasoning_llm" => 0.48 }))
    expect(result[:disposition]).to eq(:escalate)
    expect(result[:because]).to include("margin 0.04 below floor 0.20")
  end

  it "refuses outright on a hard constraint violation" do
    policy = described_class.new(floors: { route: 0.0 })
    result = policy.apply(answers, constraint_checks: [
                            { name: :no_pii, satisfied: false, hard: true, because: "DPA" }
                          ])
    expect(result[:disposition]).to eq(:refuse)
    expect(result[:blocking]).to eq([:no_pii])
  end

  it "records a soft violation without blocking the commitment" do
    policy = described_class.new(floors: { route: 0.0 })
    result = policy.apply(answers, constraint_checks: [
                            { name: :prefer_cheap, satisfied: false, hard: false, because: "budget" }
                          ])
    expect(result[:disposition]).to eq(:commit)
    expect(result[:soft_violations]).to eq([:prefer_cheap])
  end

  it "abstains when the answer is outside its declared space" do
    policy = described_class.new
    result = policy.apply(answers(route_value: "sonnet", route_confidence: 0.99))
    expect(result[:disposition]).to eq(:abstain)
  end

  it "escalates when the model picked the escape route itself" do
    policy = described_class.new(floors: { route: 0.5 })
    result = policy.apply(answers(route_value: "human_review", route_confidence: 0.99))
    expect(result[:disposition]).to eq(:escalate)
    expect(result[:because]).to include("escape option")
  end

  it "prefers a hard-constraint refusal over an escalation" do
    policy = described_class.new(floors: { route: 0.9 })
    result = policy.apply(answers(route_confidence: 0.1), constraint_checks: [
                            { name: :no_pii, satisfied: false, hard: true, because: "DPA" }
                          ])
    expect(result[:disposition]).to eq(:refuse)
  end

  it "can route uncertainty somewhere other than escalation" do
    policy = described_class.new(floors: { route: 0.9 }, on_uncertain: :abstain)
    expect(policy.apply(answers(route_confidence: 0.1))[:disposition]).to eq(:abstain)
  end
end
