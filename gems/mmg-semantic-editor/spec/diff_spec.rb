# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mmg::SemanticEditor::Diff do
  let(:frame) do
    { id: "Y1",
      label: "Harbour operations",
      body: "Frames what we are here to look after.",
      meanings: [
        { id: "Y1:M1",
          label: "Berth allocation is a duty of care",
          body: "A berth is not a slot on a chart.",
          clarifications: [{ id: "Y1:M1:C1", label: "Already alongside is not thereby entitled to stay.", body: "" }] },
        { id: "Y1:M2", label: "Tide windows bind everyone equally", body: "", clarifications: [] }
      ] }
  end

  let(:text) { Mmg::SemanticEditor::Prose.render(frame)[:text] }

  describe "an untouched edit" do
    it "is clean, and every line is context" do
      d = described_class.of(before: frame, after: text)
      expect(d[:ok]).to be true
      expect(d[:clean]).to be true
      expect(d[:lines]).to all(start_with(" "))
    end

    it "says so in one line" do
      d = described_class.of(before: frame, after: text)
      expect(described_class.summary(d)[:text]).to eq("No change.")
    end
  end

  describe "a reworded meaning" do
    let(:edited) { text.sub("A berth is not a slot on a chart.", "A berth decides whose livelihood is interrupted.") }

    it "shows the old line removed and the new line added" do
      d = described_class.of(before: frame, after: edited)
      expect(d[:changed]).to eq(["Y1:M1"])
      expect(d[:text]).to include("-  A berth is not a slot on a chart.")
      expect(d[:text]).to include("+  A berth decides whose livelihood is interrupted.")
    end

    it "reads as ONE change, not a deletion beside an unrelated addition" do
      d = described_class.of(before: frame, after: edited)
      expect(d[:added]).to be_empty
      expect(d[:removed]).to be_empty
      expect(described_class.summary(d)[:text]).to eq("1 changed.")
    end

    it "leaves the untouched blocks as context" do
      d = described_class.of(before: frame, after: edited)
      expect(d[:text]).to include(" Tide windows bind everyone equally")
    end

    it "keeps the unchanged heading as context rather than removing and re-adding it" do
      d = described_class.of(before: frame, after: edited)
      headings = d[:lines].select { |l| l.include?("Berth allocation is a duty of care") }
      expect(headings.length).to eq(1)
      expect(headings.first).to start_with(" ")
    end

    it "marks the heading when the heading itself changed" do
      retitled = text.sub("Berth allocation is a duty of care", "Berth allocation is a duty owed")
      d = described_class.of(before: frame, after: retitled)
      expect(d[:text]).to include("-  Berth allocation is a duty of care")
      expect(d[:text]).to include("+  Berth allocation is a duty owed")
      expect(d[:text]).to include("   A berth is not a slot on a chart.")
    end
  end

  describe "an added clarification" do
    let(:edited) { "#{text}\n    [Y1:M2:C1] A window missed by weather is not forfeited.\n" }

    it "marks every line of the new block with a plus" do
      d = described_class.of(before: frame, after: edited)
      expect(d[:added]).to eq(["Y1:M2:C1"])
      expect(d[:text]).to include("+    A window missed by weather is not forfeited.")
    end
  end

  describe "a removed meaning" do
    let(:edited) { text.lines.reject { |l| l.include?("[Y1:M2]") }.join }

    it "marks it with a minus" do
      d = described_class.of(before: frame, after: edited)
      expect(d[:removed]).to eq(["Y1:M2"])
      expect(d[:text]).to include("-  Tide windows bind everyone equally")
    end

    it "keeps the removal where it was, not swept to the end" do
      d = described_class.of(before: frame, after: edited)
      lines = d[:lines].reject { |l| l.strip.empty? }
      removed_at = lines.index { |l| l.start_with?("-") }
      expect(removed_at).to eq(lines.length - 1)

      # And when something follows it, the removal stays above that thing.
      reordered = "#{edited}  [Y1:M3] A later meaning\n"
      d2 = described_class.of(before: frame, after: reordered)
      ids = d2[:lines].map { |l| l[0] }
      expect(ids.index("-")).to be < ids.index("+")
    end
  end

  describe "the canonical id is what matches two blocks" do
    it "treats a retitled block as changed, not as add-plus-remove" do
      edited = text.sub("Berth allocation is a duty of care", "Berth allocation is a duty owed")
      d = described_class.of(before: frame, after: edited)
      expect(d[:changed]).to eq(["Y1:M1"])
      expect(d[:added]).to be_empty
      expect(d[:removed]).to be_empty
    end
  end

  describe ".targets" do
    it "names the structures the edit would reach" do
      edited = "#{text.sub('A berth is not a slot on a chart.', 'Rewritten.')}\n    [Y1:M2:C1] New.\n"
      d = described_class.of(before: frame, after: edited)
      expect(described_class.targets(d)[:targets]).to eq(%i[clarifications meanings])
    end

    it "is empty when nothing changed" do
      d = described_class.of(before: frame, after: text)
      expect(described_class.targets(d)[:targets]).to be_empty
    end
  end

  describe "every line carries exactly one marker" do
    it "so the view can be read down the left edge" do
      edited = "#{text.sub('A berth is not a slot on a chart.', 'Rewritten.')}\n    [Y1:M2:C1] New.\n"
      d = described_class.of(before: frame, after: edited)
      expect(d[:lines]).to all(satisfy { |l| described_class::MARKERS.include?(l[0]) })
    end
  end

  it "refuses prose it cannot parse" do
    expect(described_class.of(before: frame, after: "[Y1:M1] orphaned meaning, no frame\n"))
      .to include(ok: false, reason: :no_frame_block)
  end
end
