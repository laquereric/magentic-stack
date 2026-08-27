# frozen_string_literal: true
require "ar_spec_helper"

RSpec.describe Mmg::Acia::AciaTerm do
  it "seeds the whole Profile 9 vocabulary, not just the SLT five" do
    expect(described_class.count).to eq(96)
    expect(Mmg::Acia::TermSeeds.enumerations.keys.size).to eq(13)
  end

  it "is idempotent" do
    before = described_class.count
    out = Mmg::Acia::TermSeeds.load!
    expect(out[:ok]).to be(true)
    expect(described_class.count).to eq(before)
  end

  # ux:heading -- the specification's own term, not a name that agrees in spelling.
  it "derives the specification's IRI" do
    expect(described_class.find_by(token: "heading").iri).to eq("https://w3id.org/cpcp/osi8/ux#heading")
    expect(described_class.column_names).not_to include("iri")
  end

  # ONE resource, two positions. Five tables would have made two rows here.
  it "keeps a term legal in two enumerations as ONE row" do
    t = described_class.find_by(token: "table")
    expect(t.enumeration_names).to contain_exactly("semanticRole", "layoutKind")
    expect(described_class.where(token: "table").count).to eq(1)
  end

  it "fetches a term for a position it is legal in" do
    expect(described_class.fetch!("semanticRole", "table").token).to eq("table")
    expect(described_class.fetch!("layoutKind", "table").token).to eq("table")
  end

  # Closed AND position-sensitive: heading is a real term, but not a layoutKind.
  it "refuses a real term used in the wrong position" do
    expect { described_class.fetch!("layoutKind", "heading") }
      .to raise_error(ArgumentError, /not a legal layoutKind.*semanticRole/m)
  end

  it "refuses a token that is not in the vocabulary at all" do
    expect { described_class.fetch!("semanticRole", "headding") }
      .to raise_error(ArgumentError, /not a term in the Profile 9 vocabulary/)
    expect(described_class.count).to eq(96)
  end

  it "carries the enumerations the spec has beyond the SLT five" do
    %w[componentKind variantName eventKind ledgerPlacement tokenCategory relation overridePolicy emotion]
      .each { |e| expect(described_class.in_enumeration(e).count).to be > 0, "#{e} unseeded" }
  end
end
