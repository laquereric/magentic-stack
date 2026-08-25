# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mmg::SemanticEditor::Prose do
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

  describe ".render" do
    it "puts a canonical id at the head of every block" do
      text = described_class.render(frame)[:text]
      expect(text).to include("[Y1] Harbour operations")
      expect(text).to include("[Y1:M1] Berth allocation is a duty of care")
      expect(text).to include("[Y1:M1:C1] Already alongside")
    end

    it "indents by kind so the nesting is legible" do
      lines = described_class.render(frame)[:text].lines.map(&:chomp)
      expect(lines.find { |l| l.include?("[Y1]") }).to start_with("[Y1]")
      expect(lines.find { |l| l.include?("[Y1:M1]") }).to start_with("  [")
      expect(lines.find { |l| l.include?("[Y1:M1:C1]") }).to start_with("    [")
    end

    it "refuses to render anything but a frame" do
      r = described_class.render({ id: "Y1:M1", label: "x" })
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:not_a_frame)
    end
  end

  describe ".parse" do
    it "round-trips a rendered frame" do
      parsed = described_class.parse(described_class.render(frame)[:text])
      expect(parsed[:ok]).to be true
      expect(parsed[:frame][:id]).to eq("Y1")
      expect(parsed[:frame][:label]).to eq("Harbour operations")
      expect(parsed[:frame][:meanings].map { |m| m[:id] }).to eq(["Y1:M1", "Y1:M2"])
      expect(parsed[:frame][:meanings].first[:clarifications].map { |c| c[:id] }).to eq(["Y1:M1:C1"])
      expect(parsed[:problems]).to be_empty
    end

    it "keeps a retyped body as the block's body" do
      text = "[Y1] Harbour operations\nA rewritten sentence.\nAnd a second one.\n"
      parsed = described_class.parse(text)
      expect(parsed[:frame][:body]).to eq("A rewritten sentence. And a second one.")
    end

    it "reports a line that precedes any header rather than attaching it to something" do
      parsed = described_class.parse("stray text\n[Y1] Harbour operations\n")
      expect(parsed[:ok]).to be true
      expect(parsed[:problems].map { |p| p[:reason] }).to include(:orphan_line)
    end

    it "reports an unparseable id and does not attach the lines that follow it" do
      parsed = described_class.parse("[Y1] Frame\n[Q9:Z] junk\ntrailing\n")
      expect(parsed[:problems].map { |p| p[:reason] }).to include(:unrecognized_id, :orphan_line)
    end

    it "refuses prose with no frame header at all" do
      expect(described_class.parse("[Y1:M1] a meaning alone\n"))
        .to include(ok: false, reason: :no_frame_block)
    end

    it "reports a second frame, because prose edits one frame at a time" do
      parsed = described_class.parse("[Y1] One\n\n[Y2] Two\n")
      expect(parsed[:problems].map { |p| p[:reason] }).to include(:multiple_frames)
    end

    it "reports a meaning that belongs to a different frame" do
      parsed = described_class.parse("[Y1] One\n\n  [Y2:M1] Belongs elsewhere\n")
      expect(parsed[:problems].map { |p| p[:reason] }).to include(:cross_frame)
    end
  end

  describe ".diff" do
    it "sees nothing changed in an untouched round trip" do
      d = described_class.diff(frame, described_class.render(frame)[:text])
      expect(d[:added]).to be_empty
      expect(d[:removed]).to be_empty
      expect(d[:changed]).to be_empty
    end

    it "names the block whose text was rewritten" do
      edited = described_class.render(frame)[:text].sub("A berth is not a slot on a chart.",
                                                       "A berth decides whose livelihood is interrupted.")
      expect(described_class.diff(frame, edited)[:changed]).to eq(["Y1:M1"])
    end

    it "treats a new id as an addition and a vanished id as a removal" do
      edited = "#{described_class.render(frame)[:text]}\n    [Y1:M2:C1] A new clarification.\n"
      d = described_class.diff(frame, edited)
      expect(d[:added]).to eq(["Y1:M2:C1"])

      shortened = described_class.render(frame)[:text].lines.reject { |l| l.include?("[Y1:M2]") }.join
      expect(described_class.diff(frame, shortened)[:removed]).to eq(["Y1:M2"])
    end
  end
end
