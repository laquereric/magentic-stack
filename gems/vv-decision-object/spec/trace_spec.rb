# frozen_string_literal: true

require "json"

RSpec.describe Vv::DecisionObject::Trace do
  subject(:trace) { described_class.new(clock: fixed_clock) }

  it "appends in order with a monotonic sequence" do
    trace.append(:instantiated, decision: "do_1")
    trace.append(:answered, question: :route, value: "fast_llm")

    expect(trace.size).to eq(2)
    expect(trace.to_a.map { |e| e[:seq] }).to eq([0, 1])
    expect(trace.to_a.map { |e| e[:kind] }).to eq(%i[instantiated answered])
  end

  it "stamps every entry from the injected clock" do
    trace.append(:one)
    trace.append(:two)
    stamps = trace.to_a.map { |e| e[:at] }
    expect(stamps).to eq(["2026-09-20T12:00:01Z", "2026-09-20T12:00:02Z"])
  end

  it "survives a clock that raises" do
    t = described_class.new(clock: -> { raise "no clock" })
    expect(t.append(:one).at).to be_nil
  end

  it "finds entries by kind" do
    trace.append(:answered, question: :route)
    trace.append(:answered, question: :refund_requested)
    trace.append(:disposition, disposition: :commit)

    expect(trace.of_kind(:answered).size).to eq(2)
    expect(trace.last_of(:answered).payload[:question]).to eq(:refund_requested)
    expect(trace.last_of(:nothing)).to be_nil
  end

  it "serializes to JSON" do
    trace.append(:disposition, disposition: :commit, because: "cleared")
    parsed = JSON.parse(trace.to_json)
    expect(parsed.first).to include("kind" => "disposition", "disposition" => "commit")
  end

  it "renders an agent decision record as markdown" do
    trace.append(:answered, question: :route, value: "fast_llm", confidence: 0.9421)
    trace.append(:disposition, disposition: :commit, blocking: nil)

    md = trace.to_markdown(title: "route_ticket — do_abc")
    expect(md).to start_with("# route_ticket — do_abc")
    expect(md).to include("## 0. answered — 2026-09-20T12:00:01Z")
    expect(md).to include("- **confidence**: 0.9421")
    expect(md).to include("- **blocking**: —")
  end

  it "starts empty" do
    expect(trace).to be_empty
  end
end
