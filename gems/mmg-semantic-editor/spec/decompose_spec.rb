# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mmg::SemanticEditor::Decompose do
  let(:before_doc) { Fixtures.frame_document }
  let(:after_doc) { Fixtures.edited_document }

  describe ".plan" do
    it "turns one edit session into several edits, grouped by target structure" do
      plan = described_class.plan(before: before_doc, after: after_doc)
      expect(plan[:ok]).to be true
      expect(plan[:by_target].keys).to match_array(%i[frames clarifications])
      expect(plan[:count]).to eq(2)
    end

    it "names the rewritten frame as an update and says which props moved" do
      plan = described_class.plan(before: before_doc, after: after_doc)
      update = plan[:edits].find { |e| e[:canonical_id] == "Y1" }
      expect(update[:op]).to eq(:update)
      expect(update[:target]).to eq(:frames)
      expect(update[:changed]).to eq(["body"])
    end

    it "names the added clarification as a create, carrying its tier" do
      plan = described_class.plan(before: before_doc, after: after_doc)
      create = plan[:edits].find { |e| e[:canonical_id] == "Y1:M2:C1" }
      expect(create[:op]).to eq(:create)
      expect(create[:target]).to eq(:clarifications)
      expect(create[:tier]).to eq(:sidebar)
    end

    it "finds nothing to do when the document is unchanged" do
      plan = described_class.plan(before: before_doc, after: Fixtures.frame_document)
      expect(plan[:edits]).to be_empty
      expect(plan[:coherent]).to be true
    end

    it "refuses an edit addressed to a Translation, which is derived" do
      edited = Fixtures.deep_dup(before_doc)
      Fixtures.find(edited["rootNode"], "n-x1y1")["props"]["label"] = "hand-written translation"

      plan = described_class.plan(before: before_doc, after: edited)
      expect(plan[:coherent]).to be false
      expect(plan[:refusals].map { |r| r[:reason] }).to include(:derived_not_writable)
    end

    it "refuses a delete that would strand something held at a deeper tier" do
      shortened = Fixtures.deep_dup(before_doc)
      frame = Fixtures.find(shortened["rootNode"], "n-y1")
      m1 = Fixtures.find(shortened["rootNode"], "n-y1m1")
      frame["children"].delete(m1)
      frame["children"] << Fixtures.node("orphan-holder", "DataItem", canonical_id: "Y1:M1:C1", tier: :sidebar)

      plan = described_class.plan(before: before_doc, after: shortened)
      orphan = plan[:refusals].find { |r| r[:reason] == :would_orphan }
      expect(orphan[:canonical_id]).to eq("Y1:M1")
      expect(orphan[:because]).to include("Y1:M1:C1")
      expect(plan[:coherent]).to be false
    end
  end

  describe ".apply" do
    it "writes each target once, with all of its edits together" do
      plan = described_class.plan(before: before_doc, after: after_doc)
      seen = []
      r = described_class.apply(plan) do |target, edits|
        seen << [target, edits.length]
        { ok: true }
      end

      expect(r).to include(ok: true, applied: 2)
      expect(seen).to match_array([[:frames, 1], [:clarifications, 1]])
    end

    it "refuses an incoherent plan before writing anything" do
      edited = Fixtures.deep_dup(before_doc)
      Fixtures.find(edited["rootNode"], "n-x1y1")["props"]["label"] = "hand-written"
      plan = described_class.plan(before: before_doc, after: edited)

      wrote = false
      r = described_class.apply(plan) { |_, _| wrote = true; { ok: true } }

      expect(wrote).to be false
      expect(r).to include(ok: false, reason: :incoherent_plan)
    end

    it "stops at the first refused write and reports what had already landed" do
      plan = described_class.plan(before: before_doc, after: after_doc)
      calls = 0
      r = described_class.apply(plan) do |_, _|
        calls += 1
        calls == 1 ? { ok: true } : { ok: false, because: "store is read-only" }
      end

      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:write_refused)
      expect(r[:because]).to include("read-only")
      expect(r[:applied].length).to eq(1)
      expect(calls).to eq(2)
    end

    it "orders the writes create, then update, then delete" do
      plan = described_class.plan(before: before_doc, after: after_doc)
      expect(plan[:edits].map { |e| e[:op] }).to eq(%i[create update])
    end

    it "needs no writer when there is nothing to write" do
      plan = described_class.plan(before: before_doc, after: Fixtures.frame_document)
      expect(described_class.apply(plan)).to include(ok: true, applied: 0)
    end

    it "refuses to apply without a writer when there is work to do" do
      plan = described_class.plan(before: before_doc, after: after_doc)
      expect(described_class.apply(plan)).to include(ok: false, reason: :no_writer)
    end

    it "refuses something that is not a plan" do
      expect(described_class.apply({ ok: true })).to include(ok: false, reason: :no_plan)
    end
  end
end
