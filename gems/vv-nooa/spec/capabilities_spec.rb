# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Nooa::Capabilities do
  it "models exactly the six NOOA capabilities" do
    expect(described_class.count).to eq(6)
    expect(described_class.keys).to contain_exactly(
      :typed_io, :pass_by_reference, :code_as_action,
      :programmable_loop, :explicit_object_state, :model_callable_apis)
  end

  it "gives every capability a NVIDIA form, a stack realization, and a steal lesson" do
    described_class.all.each do |c|
      expect(c.nvidia).not_to be_empty
      expect(c.mm).not_to be_empty
      expect(c.steal).not_to be_empty
    end
  end

  it "fetches a known capability" do
    r = described_class.fetch(:pass_by_reference)
    expect(r[:ok]).to be(true)
    expect(r[:capability].title).to eq("Pass-by-reference")
  end

  it "refuses an unknown capability without raising (never-raise)" do
    r = described_class.fetch(:nope)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:unknown_capability)
  end

  it "maps onto magentic-stack terms, not Magentic Market leftovers" do
    blob = described_class.all.map(&:mm).join(" ")
    expect(blob).not_to match(/Schematist|mmg-uut|GalaxyGate|shell_exec/)
    expect(described_class.fetch(:code_as_action)[:capability].mm).to include("Monty")
    expect(described_class.fetch(:pass_by_reference)[:capability].mm).to include("Profile 2")
  end
end
