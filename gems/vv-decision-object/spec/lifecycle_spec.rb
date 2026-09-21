# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Lifecycle do
  it "walks the designed → audited path" do
    %i[designed instantiated executed monitored audited].each_cons(2) do |from, to|
      expect(described_class.transition(from, to)[:ok]).to be(true)
    end
  end

  it "lets an audited object be revised and re-instantiated" do
    expect(described_class.allowed?(:audited, :revised)).to be(true)
    expect(described_class.allowed?(:revised, :instantiated)).to be(true)
  end

  it "refuses a transition that skips the middle" do
    result = described_class.transition(:designed, :audited)
    expect(result[:ok]).to be(false)
    expect(result[:reason]).to eq(:illegal_transition)
    expect(result[:because]).to include("may only become instantiated, decommissioned")
  end

  it "treats decommissioned as terminal" do
    expect(described_class).to be_terminal(:decommissioned)
    result = described_class.transition(:decommissioned, :instantiated)
    expect(result[:because]).to include("terminal")
  end

  it "lets any live state be decommissioned" do
    (described_class::STATES - [:decommissioned]).each do |state|
      expect(described_class.allowed?(state, :decommissioned)).to be(true)
    end
  end

  it "refuses an unknown state rather than raising" do
    expect(described_class.transition(:executed, :vibes)[:reason]).to eq(:unknown_state)
    expect(described_class.transition(:vibes, :executed)[:reason]).to eq(:unknown_state)
  end
end
