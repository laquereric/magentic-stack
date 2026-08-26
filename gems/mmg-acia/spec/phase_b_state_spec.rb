# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "spec_helper"

RSpec.describe "ACIA Phase B — state / transition / validated snapshot" do
  describe Mmg::Acia::State do
    it "normalizes tab selected boolean" do
      r = described_class.normalize("tab", "selected" => true)
      expect(r[:ok]).to be true
      expect(r[:state]["selected"]).to be true
      expect(r[:state_profile_version]).to eq("1")
    end

    it "rejects unknown keys for tab" do
      r = described_class.normalize("tab", "hover" => true)
      expect(r[:ok]).to be false
    end

    it "does not coerce absence to false" do
      r = described_class.normalize("tab", {})
      expect(r[:ok]).to be true
      expect(r[:state]).to eq({})
    end

    it "validates sample tablist topology (exactly one selected)" do
      tree = Mmg::Acia::TabTree.sample(selected: "billing")
      r = described_class.validate_tree(tree)
      expect(r[:ok]).to be true
      expect(r[:conforms]).to be true
    end

    it "fails zero-selected tablist" do
      r = described_class.validate_tree(Mmg::Acia::TabTree.zero_selected)
      expect(r[:conforms]).to be false
      expect(r[:results].any? { |i| i[:message].include?("exactly one") }).to be true
    end

    it "fails dual-selected tablist" do
      r = described_class.validate_tree(Mmg::Acia::TabTree.dual_selected)
      expect(r[:conforms]).to be false
    end

    it "emits typed state triples" do
      t = described_class.state_triples(
        "urn:mm:acia:tab:billing",
        "tab",
        "selected" => true
      )
      expect(t.join).to include("aria#selected")
      expect(t.join).to include("true")
      expect(t.join).to include("stateProfileVersion")
    end
  end

  describe Mmg::Acia::Transition do
    let(:tree) { Mmg::Acia::TabTree.sample(selected: "billing") }

    it "selects another tab with exclusive selection" do
      r = described_class.select_tab(tree, entity_token: "urn:mm:acia:tab:usage")
      expect(r[:ok]).to be true
      expect(r[:topology_conforms]).to be true
      tabs = r[:candidate][:children][0][:children]
      selected = tabs.select { |t| t[:semantic_state]["selected"] }
      expect(selected.size).to eq(1)
      expect(selected.first[:entity_token]).to eq("urn:mm:acia:tab:usage")
    end

    it "refuses stale expected_revision" do
      rev = described_class.tree_revision(tree)
      r = described_class.select_tab(
        tree,
        entity_token: "urn:mm:acia:tab:usage",
        expected_revision: "r_stale"
      )
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:revision_conflict)
      expect(r[:refreshable]).to be true
      expect(r[:current_revision]).to eq(rev)
    end

    it "refuses unknown entity_token" do
      r = described_class.select_tab(tree, entity_token: "urn:mm:acia:tab:nope")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:unknown_token)
    end
  end

  describe Mmg::Acia::ValidatedSnapshot do
    it "accepts valid sample tree under enforce" do
      r = described_class.from_tree(Mmg::Acia::TabTree.sample, enforce: true, shacl: false)
      expect(r[:ok]).to be true
      expect(r[:conforms]).to be true
      expect(r[:snapshot]["schema"]).to eq("AciaValidatedSnapshot.v1")
      expect(r[:snapshot]["profile"]).to eq("acia_core_enforcing")
    end

    it "blocks dual-selected under enforce" do
      r = described_class.from_tree(Mmg::Acia::TabTree.dual_selected, enforce: true, shacl: false)
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:validation_failed)
      expect(r[:conforms]).to be false
    end

    it "select_and_validate runs transition then gate" do
      tree = Mmg::Acia::TabTree.sample(selected: "billing")
      r = described_class.select_and_validate(
        tree,
        entity_token: "urn:mm:acia:tab:settings",
        enforce: true
      )
      expect(r[:ok]).to be true
      expect(r[:action]).to eq("select")
      tabs = r.dig(:snapshot, "tree", :children, 0, :children) ||
             r.dig(:snapshot, "tree", "children", 0, "children")
      # keys may be symbols from deep_dup
      tabs = r[:transition][:candidate][:children][0][:children]
      sel = tabs.find { |t| t[:semantic_state]["selected"] }
      expect(sel[:entity_token]).to eq("urn:mm:acia:tab:settings")
    end
  end

  describe "facade" do
    it "exposes Phase B helpers on Mmg::Acia" do
      expect(Mmg::Acia.version).to match(/\d+\.\d+\.\d+/)
      tree = Mmg::Acia.sample_tab_tree(selected: "usage")
      expect(Mmg::Acia.validate_tree_state(tree)[:conforms]).to be true
      expect(Mmg::Acia.select_tab(tree, entity_token: "urn:mm:acia:tab:billing")[:ok]).to be true
    end
  end
end
