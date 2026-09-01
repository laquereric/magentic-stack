# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Adr::Chain do
  def attrs(**over)
    { "title" => "t", "status" => "accepted",
      "enforced_by" => ["spec/x_spec.rb"], "paths" => ["lib/x"] }.merge(over.transform_keys(&:to_s))
  end

  it "reports a complete chain" do
    expect(described_class.break_at(attrs)).to be_nil
    expect(described_class.complete?(attrs)).to be(true)
  end

  # Naming the broken link is the point: a boolean tells you something is wrong
  # and leaves you to find out what.
  it "names the missing link rather than returning false" do
    expect(described_class.break_at(attrs("enforced_by" => []))).to eq(:constraint)
    expect(described_class.break_at(attrs("paths" => []))).to eq(:code)
    expect(described_class.break_at(attrs("title" => ""))).to eq(:decision)
  end

  it "reports the first break, since a decision with no enforcement has no mechanism to point at code" do
    expect(described_class.break_at(attrs("title" => "", "enforced_by" => [], "paths" => []))).to eq(:decision)
  end

  it "does not treat explicit unenforced as a missing constraint" do
    expect(described_class.break_at(attrs("enforced_by" => [], "unenforced" => true))).to be_nil
    expect(described_class.break_at(attrs("enforced_by" => []))).to eq(:constraint)
  end

  # A dead ADR is worse than no ADR: still in search reach, obeyed after the code
  # it governs has moved.
  it "finds declared paths that no longer resolve" do
    exists = ->(p) { p == "lib/x" }
    found = described_class.dangling(attrs, exists: exists)
    expect(found).to eq(["spec/x_spec.rb"])
  end

  it "finds nothing dangling when every declared path resolves" do
    expect(described_class.dangling(attrs, exists: ->(_p) { true })).to be_empty
  end
end
