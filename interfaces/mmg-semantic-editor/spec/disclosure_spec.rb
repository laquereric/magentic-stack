# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mmg::SemanticEditor::Disclosure do
  describe ".tier" do
    it "reads a declared tier" do
      node = Fixtures.node("n", "DataItem", tier: :sidebar)
      expect(described_class.tier(node)).to include(ok: true, tier: :sidebar, defaulted: false)
    end

    it "defaults to immediate, and says so" do
      node = Fixtures.node("n", "DataItem")
      expect(described_class.tier(node)).to include(ok: true, tier: :immediate, defaulted: true)
    end

    it "refuses a tier outside the closed set rather than inventing one" do
      node = Fixtures.node("n", "DataItem", tier: :footnote)
      r = described_class.tier(node)
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:unknown_tier)
      expect(r[:because]).to include("immediate")
    end

    it "refuses something that is not a node" do
      expect(described_class.tier("sidebar")).to include(ok: false, reason: :no_node)
    end
  end

  describe ".deeper?" do
    it "orders the tiers shallowest to deepest" do
      expect(described_class.deeper?(:sidebar, :immediate)).to be true
      expect(described_class.deeper?(:hover, :sidebar)).to be false
      expect(described_class.deeper?(:detail, :hover)).to be true
    end

    it "is false when a tier cannot be placed" do
      expect(described_class.deeper?(:footnote, :immediate)).to be false
    end

    it "is false for a tier compared with itself" do
      expect(described_class.deeper?(:hover, :hover)).to be false
    end
  end

  describe ".visible_at" do
    it "includes every tier at or above the one asked for" do
      expect(described_class.visible_at(:sidebar)[:tiers]).to eq(%i[immediate hover sidebar])
    end

    it "shows only the immediate tier at rest" do
      expect(described_class.visible_at(:immediate)[:tiers]).to eq([:immediate])
    end

    it "refuses an unknown tier" do
      expect(described_class.visible_at(:footnote)).to include(ok: false, reason: :unknown_tier)
    end
  end
end
