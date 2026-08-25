# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mmg::SemanticEditor do
  let(:doc) { Fixtures.frame_document }

  describe ".open" do
    it "opens a session over an admissible tree" do
      s = described_class.open(acia: doc)
      expect(s[:ok]).to be true
      expect(s[:editable]).to include("Y1", "Y1:M1")
      expect(s[:derived]).to eq(["X1:Y1"])
    end

    it "shows only the immediate tier at rest" do
      s = described_class.open(acia: doc)
      expect(s[:visible]).not_to include("Y1:M1:C1")
    end

    it "renders prose for a focused frame" do
      s = described_class.open(acia: doc, focus: "Y1")
      expect(s[:prose]).to include("[Y1] Harbour operations")
      expect(s[:prose]).to include("[Y1:M1] Berth allocation is a duty of care")
      expect(s[:prose]).to include("[Y1:M1:C1]")
      expect(s[:prose_refusal]).to be_nil
    end

    it "puts clarifications in prose even though they sit at a deeper tier" do
      s = described_class.open(acia: doc, focus: "Y1", tier: :immediate)
      expect(s[:visible]).not_to include("Y1:M1:C1")
      expect(s[:prose]).to include("Already alongside")
    end

    it "names what is hidden beneath the focused node" do
      s = described_class.open(acia: doc, focus: "Y1:M1", tier: :immediate)
      expect(s[:hidden]).to eq(["Y1:M1:C1"])
    end

    it "refuses prose over something that is not a frame, without failing the session" do
      s = described_class.open(acia: doc, focus: "X1")
      expect(s[:ok]).to be true
      expect(s[:prose]).to be_nil
      expect(s[:prose_refusal][:reason]).to eq(:prose_needs_a_frame)
    end

    it "refuses a focus that is not in the document" do
      expect(described_class.open(acia: doc, focus: "Y9"))
        .to include(ok: false, reason: :unknown_focus)
    end

    it "refuses a tree that could not be routed back" do
      bare = { "rootNode" => Fixtures.node("p", "PanelFrame") }
      expect(described_class.open(acia: bare)).to include(ok: false, reason: :no_canonical_ids)
    end
  end

  describe "open -> stage -> commit" do
    it "carries an edit through to grouped writes" do
      session = described_class.open(acia: doc, focus: "Y1")
      plan = described_class.stage(session: session, acia: Fixtures.edited_document)

      expect(plan[:coherent]).to be true
      expect(plan[:by_target].keys).to match_array(%i[frames clarifications])

      written = {}
      r = described_class.commit(plan) do |target, edits|
        written[target] = edits.map { |e| e[:canonical_id] }
        { ok: true }
      end

      expect(r[:ok]).to be true
      expect(written[:frames]).to eq(["Y1"])
      expect(written[:clarifications]).to eq(["Y1:M2:C1"])
    end

    it "refuses to stage without a session" do
      expect(described_class.stage(session: {}, acia: doc)).to include(ok: false, reason: :no_session)
    end
  end

  describe "the view" do
    it "defaults to the diff" do
      expect(described_class::DEFAULT_VIEW).to eq(:diff)
      expect(described_class.open(acia: doc, focus: "Y1")[:view]).to eq(:diff)
    end

    it "can be set to prose, because the choice is a consumer setting" do
      expect(described_class.open(acia: doc, focus: "Y1", view: :prose)[:view]).to eq(:prose)
    end

    it "refuses a view it does not have" do
      expect(described_class.open(acia: doc, focus: "Y1", view: :rendered))
        .to include(ok: false, reason: :unknown_view)
    end
  end

  describe "a staged edit carries its own diff" do
    it "shows what moved, not just the resulting text" do
      session = described_class.open(acia: doc, focus: "Y1")
      plan = described_class.stage(session: session, acia: Fixtures.edited_document)

      expect(plan[:view]).to eq(:diff)
      expect(plan[:diff]).to include("+")
      expect(plan[:diff_summary]).to include("added")
      expect(plan[:prose]).to be_a(String)
    end

    it "reports a clean diff when nothing was touched" do
      session = described_class.open(acia: doc, focus: "Y1")
      plan = described_class.stage(session: session, acia: Fixtures.frame_document)

      expect(plan[:edits]).to be_empty
      expect(plan[:diff_summary]).to eq("No change.")
      expect(plan[:diff].lines).to all(start_with(" "))
    end
  end

  it "has a version" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
