# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Nooa::HarnessComparison do
  it "quantifies the harness delta on the same model (baseline -> NOOA)" do
    d = described_class.delta(from: "baseline", to: "NOOA")
    expect(d[:ok]).to be(true)
    expect(d[:score_delta]).to eq(4.0)   # NOOA 82.2 vs baseline 78.2
    expect(d[:token_ratio]).to eq(2.0)   # baseline burned 2x the tokens
    expect(d[:call_ratio]).to eq(2.28)   # baseline made 2.28x the calls
  end

  it "refuses an unknown run without raising" do
    d = described_class.delta(from: "baseline", to: "nope")
    expect(d[:ok]).to be(false)
    expect(d[:reason]).to eq(:unknown_run)
  end
end
