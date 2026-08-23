# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mmg::SemanticEditor::CanonicalId do
  describe ".parse" do
    it "reads an Input as frame-independent" do
      r = described_class.parse("X1")
      expect(r[:ok]).to be true
      expect(r[:kind]).to eq(:input)
      expect(r).not_to have_key(:frame)
    end

    it "reads a Frame" do
      expect(described_class.parse("Y2")).to include(ok: true, kind: :frame, ordinal: 2)
    end

    it "scopes a Meaning to its Frame" do
      expect(described_class.parse("Y1:M3")).to include(ok: true, kind: :meaning, frame: "Y1", ordinal: 3)
    end

    it "scopes a Clarification to its Meaning and Frame" do
      expect(described_class.parse("Y1:M3:C2"))
        .to include(ok: true, kind: :clarification, frame: "Y1", meaning: "Y1:M3", ordinal: 2)
    end

    it "reads a Translation as the pairing of an Input and a Frame" do
      expect(described_class.parse("X1:Y2")).to include(ok: true, kind: :translation, input: "X1", frame: "Y2")
    end

    it "reads a Reference as produced, and about an Input" do
      expect(described_class.parse("X1:Y1:R1"))
        .to include(ok: true, kind: :reference, input: "X1", frame: "Y1", ordinal: 1)
    end

    it "reads a Stewardship carry" do
      expect(described_class.parse("X4:Y2:Z1"))
        .to include(ok: true, kind: :stewardship, input: "X4", frame: "Y2", ordinal: 1)
    end

    it "distinguishes a Reference from a Clarification by which side it leads with" do
      expect(described_class.parse("X1:Y1:R1")[:kind]).to eq(:reference)
      expect(described_class.parse("Y1:M1:C1")[:kind]).to eq(:clarification)
    end

    it "refuses a blank id" do
      expect(described_class.parse("  ")).to include(ok: false, reason: :blank_id)
    end

    it "refuses a shape it does not recognize rather than guessing" do
      r = described_class.parse("Q7:W2")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:unrecognized_id)
      expect(r[:because]).to include("Q7:W2")
    end
  end

  describe ".target" do
    it "routes each stored kind to its own structure" do
      expect(described_class.target("X1")[:target]).to eq(:inputs)
      expect(described_class.target("Y1")[:target]).to eq(:frames)
      expect(described_class.target("Y1:M1")[:target]).to eq(:meanings)
      expect(described_class.target("Y1:M1:C1")[:target]).to eq(:clarifications)
      expect(described_class.target("X1:Y1:R1")[:target]).to eq(:references)
      expect(described_class.target("X1:Y1:Z1")[:target]).to eq(:stewardship_carries)
    end

    it "refuses a Translation, because it is derived per request and never stored" do
      r = described_class.target("X1:Y1")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:derived_not_writable)
      expect(r[:because]).to include("derived per request")
    end
  end

  describe ".in_frame?" do
    it "treats an Input as belonging to every frame" do
      expect(described_class.in_frame?("X1", "Y1")).to be true
      expect(described_class.in_frame?("X1", "Y9")).to be true
    end

    it "holds a Meaning to its own frame" do
      expect(described_class.in_frame?("Y1:M1", "Y1")).to be true
      expect(described_class.in_frame?("Y1:M1", "Y2")).to be false
    end

    it "is false for an id it cannot parse" do
      expect(described_class.in_frame?("nonsense", "Y1")).to be false
    end
  end
end
