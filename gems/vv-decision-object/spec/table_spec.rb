# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Table do
  subject(:table) do
    described_class.new(
      :refund_authority,
      inputs: %i[amount tier],
      outputs: %i[approver],
      rules: [
        { when: { amount: ->(v) { v < 50 } }, then: { approver: "auto" } },
        { when: { amount: ->(v) { v < 500 }, tier: "premium" }, then: { approver: "agent" } },
        { when: { amount: :any, tier: :any }, then: { approver: "manager" } }
      ]
    )
  end

  it "is valid and returns the first matching rule" do
    expect(table).to be_valid
    result = table.evaluate(amount: 20, tier: "basic")
    expect(result[:ok]).to be(true)
    expect(result[:data]).to eq(approver: "auto")
    expect(result[:matched]).to eq([0])
  end

  it "falls through to the catch-all rule" do
    expect(table.evaluate(amount: 900, tier: "premium")[:data]).to eq(approver: "manager")
  end

  it "treats an omitted condition as :any" do
    expect(table.evaluate(amount: 10, tier: "premium")[:data]).to eq(approver: "auto")
  end

  it "reads string-keyed state" do
    expect(table.evaluate("amount" => 20, "tier" => "basic")[:data]).to eq(approver: "auto")
  end

  it "matches ranges, regexps and arrays" do
    t = described_class.new(
      :kind, inputs: %i[age code region], outputs: %i[band],
      rules: [{ when: { age: 18..65, code: /\Aab/i, region: %w[us ca] }, then: { band: "standard" } }]
    )
    expect(t.evaluate(age: 30, code: "AB-1", region: "ca")[:data]).to eq(band: "standard")
    expect(t.evaluate(age: 80, code: "AB-1", region: "ca")[:reason]).to eq(:no_matching_rule)
  end

  it "refuses when nothing matches" do
    t = described_class.new(:strict, inputs: %i[x], outputs: %i[y],
                                     rules: [{ when: { x: "a" }, then: { y: 1 } }])
    result = t.evaluate(x: "z")
    expect(result[:ok]).to be(false)
    expect(result[:reason]).to eq(:no_matching_rule)
    expect(result[:inputs]).to eq(x: "z")
  end

  it "refuses ambiguity under a :unique hit policy" do
    t = described_class.new(
      :overlap, inputs: %i[x], outputs: %i[y], hit_policy: :unique,
      rules: [{ when: { x: :any }, then: { y: 1 } }, { when: { x: "a" }, then: { y: 2 } }]
    )
    result = t.evaluate(x: "a")
    expect(result[:reason]).to eq(:ambiguous_rules)
    expect(result[:matched]).to eq([0, 1])
  end

  it "collects every match under a :collect hit policy" do
    t = described_class.new(
      :tags, inputs: %i[x], outputs: %i[tag], hit_policy: :collect,
      rules: [{ when: { x: :any }, then: { tag: "all" } }, { when: { x: "a" }, then: { tag: "a-only" } }]
    )
    expect(t.evaluate(x: "a")[:data]).to eq([{ tag: "all" }, { tag: "a-only" }])
    expect(t.evaluate(x: "b")[:data]).to eq([{ tag: "all" }])
  end

  it "treats a raising condition as no match rather than exploding" do
    t = described_class.new(:boom, inputs: %i[x], outputs: %i[y],
                                   rules: [{ when: { x: ->(v) { v.fetch(:nope) } }, then: { y: 1 } }])
    expect(t.evaluate(x: 1)[:reason]).to eq(:no_matching_rule)
  end

  it "names every structural problem instead of the first" do
    t = described_class.new(:bad, inputs: %i[x], outputs: %i[y z], hit_policy: :random,
                                  rules: [{ when: { q: 1 }, then: { y: 1 } }])
    expect(t).not_to be_valid
    expect(t.problems).to include(a_string_including("hit policy random"))
    expect(t.problems).to include(a_string_including("unknown input(s) q"))
    expect(t.problems).to include(a_string_including("missing output(s) z"))

    result = t.evaluate(x: 1)
    expect(result[:reason]).to eq(:table_invalid)
    expect(result[:problems].size).to eq(3)
  end

  it "renders callables as placeholders in to_h" do
    expect(table.to_h[:rules].first[:when][:amount]).to eq("<callable>")
  end
end
