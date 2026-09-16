# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Nooa::Isolation do
  it "classifies AST validation as defense-in-depth, not the boundary" do
    r = described_class.classify(:ast_validation)
    expect(r[:kind]).to eq(:defense_in_depth)
    expect(r[:is_boundary]).to be(false)
  end

  it "classifies a container as a containment boundary" do
    expect(described_class.classify(:container)[:is_boundary]).to be(true)
  end

  it "classifies Monty as a containment boundary (ADR 0071)" do
    r = described_class.classify(:monty)
    expect(r[:ok]).to be(true)
    expect(r[:kind]).to eq(:containment_boundary)
    expect(r[:is_boundary]).to be(true)
  end

  it "refuses an unknown control without raising" do
    expect(described_class.classify(:nope)[:ok]).to be(false)
  end

  it "names Monty and distroless in the doctrine, not mmg-uut" do
    expect(described_class::RULE).to include("Monty")
    expect(described_class::RULE).to include("distroless")
    expect(described_class::RULE).not_to match(/mmg-uut|GalaxyGate/)
  end
end
