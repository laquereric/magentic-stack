# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Constraint do
  it "passes when the test holds" do
    c = described_class.new(:under_limit, because: "credit limit") { |s| s[:amount] < 100 }
    expect(c.check(amount: 20)).to include(name: :under_limit, satisfied: true, hard: true)
  end

  it "fails when the test does not hold, carrying the because" do
    c = described_class.new(:under_limit, because: "credit limit is $100") { |s| s[:amount] < 100 }
    check = c.check(amount: 500)
    expect(check[:satisfied]).to be(false)
    expect(check[:because]).to eq("credit limit is $100")
  end

  it "treats an unevaluable boundary as violated rather than raising" do
    c = described_class.new(:boom, because: "x") { |s| s.fetch(:missing).length }
    check = c.check({})
    expect(check[:satisfied]).to be(false)
    expect(check[:error]).to include("KeyError")
  end

  it "supports soft constraints that record without blocking" do
    c = described_class.new(:prefer_cheap, because: "budget", hard: false) { false }
    expect(c.check({})).to include(satisfied: false, hard: false)
  end

  it "accepts a zero-arity test" do
    c = described_class.new(:always, because: "x") { true }
    expect(c.check({})[:satisfied]).to be(true)
  end

  it "needs a because and a test block" do
    c = described_class.new(:bare, because: "")
    expect(c).not_to be_valid
    expect(c.problems).to include(a_string_including("`because` is required"))
    expect(c.problems).to include(a_string_including("no test block"))
    expect(c.check({})[:satisfied]).to be(false)
  end
end
