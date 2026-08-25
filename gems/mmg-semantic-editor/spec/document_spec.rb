# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mmg::SemanticEditor::Document do
  let(:doc) { Fixtures.frame_document }

  describe ".index" do
    it "finds every node that carries a canonical id" do
      idx = described_class.index(doc)
      expect(idx[:ok]).to be true
      expect(idx[:entries].keys).to match_array(%w[X1 Y1 Y1:M1 Y1:M1:C1 Y1:M2 X1:Y1])
    end

    it "treats a node without a canonical id as chrome, not as a problem" do
      idx = described_class.index(doc)
      expect(idx[:chrome]).to include("pnl-1", "hd-1")
      expect(idx[:problems]).to be_empty
    end

    it "separates what can be written from what is derived" do
      idx = described_class.index(doc)
      expect(idx[:derived]).to eq(["X1:Y1"])
      expect(idx[:editable]).not_to include("X1:Y1")
    end

    it "records each entry's tier" do
      idx = described_class.index(doc)
      expect(idx[:entries]["Y1:M1"][:tier]).to eq(:immediate)
      expect(idx[:entries]["Y1:M1:C1"][:tier]).to eq(:sidebar)
    end

    it "inherits a tier down the subtree unless a child declares its own" do
      tree = { "rootNode" => Fixtures.node("p", "PanelFrame", canonical_id: "Y1", tier: :sidebar, children: [
                                            Fixtures.node("m", "DataItem", canonical_id: "Y1:M1")
                                          ]) }
      expect(described_class.index(tree)[:entries]["Y1:M1"][:tier]).to eq(:sidebar)
    end

    it "reports a canonical id used twice instead of silently keeping one" do
      tree = { "rootNode" => Fixtures.node("p", "PanelFrame", children: [
                                            Fixtures.node("a", "DataItem", canonical_id: "Y1:M1"),
                                            Fixtures.node("b", "DataItem", canonical_id: "Y1:M1")
                                          ]) }
      problems = described_class.index(tree)[:problems]
      expect(problems.map { |p| p[:reason] }).to include(:duplicate_canonical_id)
    end

    it "refuses a document with no root" do
      expect(described_class.index({ "nodes" => [] })).to include(ok: false, reason: :no_root)
    end

    it "accepts either rootNode or root" do
      alt = { "root" => doc["rootNode"] }
      expect(described_class.index(alt)[:entries].keys).to include("Y1")
    end
  end

  describe ".admissible?" do
    it "accepts a tree whose nodes can be routed back" do
      expect(described_class.admissible?(doc)[:ok]).to be true
    end

    it "refuses a tree with no canonical ids at all, up front" do
      tree = { "rootNode" => Fixtures.node("p", "PanelFrame", children: [Fixtures.node("h", "Heading")]) }
      r = described_class.admissible?(tree)
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:no_canonical_ids)
      expect(r[:because]).to include("could not be routed back")
    end

    it "refuses a tree carrying an unroutable id" do
      tree = { "rootNode" => Fixtures.node("p", "PanelFrame", children: [
                                            Fixtures.node("a", "DataItem", canonical_id: "Y1"),
                                            Fixtures.node("b", "DataItem", canonical_id: "W9:Q2")
                                          ]) }
      r = described_class.admissible?(tree)
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:unroutable_nodes)
    end
  end

  describe ".at_tier" do
    it "shows only the immediate tier at rest" do
      r = described_class.at_tier(doc, :immediate)
      expect(r[:entries].keys).not_to include("Y1:M1:C1")
    end

    it "includes deeper entries once the tier is opened" do
      r = described_class.at_tier(doc, :sidebar)
      expect(r[:entries].keys).to include("Y1:M1:C1")
    end
  end

  describe ".hidden_beneath" do
    it "names what is attached below the tier being edited" do
      r = described_class.hidden_beneath(doc, "Y1:M1", :immediate)
      expect(r[:ok]).to be true
      expect(r[:hidden]).to eq(["Y1:M1:C1"])
    end

    it "finds nothing hidden once the deeper tier is open" do
      expect(described_class.hidden_beneath(doc, "Y1:M1", :sidebar)[:hidden]).to be_empty
    end

    it "refuses an id that is not in the document" do
      expect(described_class.hidden_beneath(doc, "Y9", :immediate)).to include(ok: false, reason: :unknown_id)
    end
  end
end
