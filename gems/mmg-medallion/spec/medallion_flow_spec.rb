# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "spec_helper"

RSpec.describe "mmg_medallion_flow" do
  before do
    Mmg::Medallion::Tier.clear_memory!
    Mmg::Medallion::MedallionFlow.clear!
    Mmg::Medallion::GraphProjection.clear!
  end

  describe "Seed" do
    it "idempotently seeds Bronze/Silver/Gold" do
      r1 = Mmg::Medallion.seed
      expect(r1[:ok]).to eq(true)
      expect(r1[:seeded]).to eq(%w[bronze silver gold])
      expect(r1[:count]).to eq(3)

      r2 = Mmg::Medallion.seed
      expect(r2[:ok]).to eq(true)
      expect(r2[:seeded]).to eq(%w[bronze silver gold])

      bronze = Mmg::Medallion::Tier.for("bronze")
      expect(bronze.name).to eq("Bronze")
      expect(bronze.rank).to eq(1)
      expect(bronze.iri).to include("medallion/bronze")
    end
  end

  describe "Tier triples (Storable grounding)" do
    it "emits tier + promotesToTier triples" do
      Mmg::Medallion.seed
      silver = Mmg::Medallion::Tier.for("silver")
      triples = silver.emit_triples
      expect(triples).not_to be_empty
      types = triples.select { |t| t[:p] == Mmg::Medallion::Vocab::RDF_TYPE }
      expect(types.first[:o]).to eq(Mmg::Medallion::Vocab::MEDALLION_TIER)
      promo = triples.find { |t| t[:p] == Mmg::Medallion::Vocab::PROMOTES_TO_TIER }
      expect(promo[:o]).to eq(Mmg::Medallion::Vocab.tier("gold"))
    end
  end

  describe "FlowTemplate DSL" do
    it "builds stamps for all stages" do
      r = Mmg::Medallion.template("doc_refine") do
        bronze { stamp source: "ingest" }
        silver { stamp quality: "0.9" }
        gold { stamp curated: "true" }
      end
      expect(r[:ok]).to eq(true)
      tpl = r[:template]
      expect(tpl.stamps_for("bronze").first["key"]).to eq("source")
      expect(tpl.stamps_for("gold").first["value"]).to eq("true")
    end

    it "rejects missing stages" do
      r = Mmg::Medallion::FlowTemplate::Builder.new(key: "bad").tap { |b|
        b.bronze { stamp x: "1" }
      }.build
      expect(r[:ok]).to eq(false)
      expect(r[:reason]).to eq(:invalid_flow_template)
    end
  end

  describe "MedallionFlow start + promote" do
    let(:subject_iri) { "urn:mm:doc:example-1" }

    it "starts at bronze with grounding triples" do
      r = Mmg::Medallion.start_flow(subject: subject_iri, template: "default")
      expect(r[:ok]).to eq(true)
      expect(r[:flow][:current_tier]).to eq("bronze")
      expect(r[:grounding].any? { |t| t[:p] == Mmg::Medallion::Vocab::MEDALLION_TIER_P }).to eq(true)
      expect(r[:grounding].first[:o]).to include("bronze")
    end

    it "promotes bronze→silver→gold and rejects non-adjacent" do
      Mmg::Medallion.start_flow(subject: subject_iri)
      bad = Mmg::Medallion.promote(subject: subject_iri, to: "gold")
      expect(bad[:ok]).to eq(false)
      expect(bad[:reason]).to eq(:illegal_transition)

      s = Mmg::Medallion.promote(subject: subject_iri, to: "silver")
      expect(s[:ok]).to eq(true)
      expect(s[:tier][:slug]).to eq("silver")
      expect(s[:promotion_triples].any? { |t| t[:p] == Mmg::Medallion::Vocab::PROMOTED_TO }).to eq(true)

      g = Mmg::Medallion.promote(subject: subject_iri, to: "gold")
      expect(g[:ok]).to eq(true)
      expect(g[:flow][:current_tier]).to eq("gold")

      cur = Mmg::Medallion.current(subject: subject_iri)
      expect(cur[:ok]).to eq(true)
      expect(cur[:tier][:slug]).to eq("gold")
    end
  end

  describe "SalView ACIA" do
    it "projects single subtree with tier children states" do
      subj = "urn:mm:doc:sal-1"
      Mmg::Medallion.start_flow(subject: subj)
      Mmg::Medallion.promote(subject: subj, to: "silver")
      v = Mmg::Medallion.sal_view(subject: subj)
      expect(v[:ok]).to eq(true)
      node = v[:node]
      expect(node["semantic_role"]).to eq("medallion_flow")
      expect(node["children"].size).to eq(3)
      bronze = node["children"].find { |c| c["properties"]["rank"] == 1 }
      silver = node["children"].find { |c| c["properties"]["rank"] == 2 }
      gold = node["children"].find { |c| c["properties"]["rank"] == 3 }
      expect(bronze["state"]).to eq("complete")
      expect(silver["state"]).to eq("current")
      expect(gold["state"]).to eq("pending")
    end
  end

  describe "mcb_actions" do
    it "exposes seed/flow/promote/current/sal_view" do
      names = Mmg::Medallion.mcb_actions.map { |a| a[:name] }
      expect(names).to include(
        "medallion_seed", "medallion_flow_start", "medallion_promote",
        "medallion_current", "medallion_sal_view", "medallion_template"
      )
    end
  end

  describe "legacy surfaces intact" do
    it "still registers projection flows and layer contracts" do
      b = Mmg::Medallion.layer("bronze")
      expect(b[:ok]).to eq(true)
      f = Mmg::Medallion.register_flow("gm_x", target_tier: "silver", shape_set: "x")
      expect(f.name).to eq("gm_x")
      found = Mmg::Medallion.flow("gm_x")
      expect(found).to eq(f)
    end
  end
end
