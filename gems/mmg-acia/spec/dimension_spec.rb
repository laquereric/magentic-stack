# frozen_string_literal: true
require "ar_spec_helper"

RSpec.describe Mmg::Acia::Dimension do
  let(:roles) { Mmg::Acia::Dimensions::SemanticRole }

  it "seeds all five closed vocabularies" do
    expect(DIMENSION_MODELS.map(&:count)).to eq([14, 12, 7, 4, 8])
  end

  it "is idempotent -- re-seeding writes nothing new" do
    before = DIMENSION_MODELS.map(&:count)
    out = Mmg::Acia::DimensionSeeds.load!

    expect(out[:ok]).to be(true)
    expect(out[:created]).to eq(0)
    expect(DIMENSION_MODELS.map(&:count)).to eq(before)
  end

  # A row that can name its own IRI can name someone else's.
  it "derives the IRI from (dimension, token) rather than storing it" do
    expect(roles.for_token("heading").iri).to eq("urn:mm:vocab/acia#semanticRole/heading")
    expect(roles.column_names).not_to include("iri")
  end

  # "table" is a legal semanticRole AND a legal layoutKind. One shared table keyed
  # by token would collapse them into a single row meaning two things.
  it "keeps a token that appears in two dimensions distinct" do
    a = roles.for_token("table")
    b = Mmg::Acia::Dimensions::LayoutKind.for_token("table")

    expect(a).to be_present
    expect(b).to be_present
    expect(a.iri).to eq("urn:mm:vocab/acia#semanticRole/table")
    expect(b.iri).to eq("urn:mm:vocab/acia#layoutKind/table")
    expect(a.iri).not_to eq(b.iri)
  end

  it "does the same for timeline, the other overlapping token" do
    expect(roles.for_token("timeline").iri)
      .not_to eq(Mmg::Acia::Dimensions::LayoutKind.for_token("timeline").iri)
  end

  it "refuses a duplicate token -- two rows for heading is two answers to one question" do
    dup = roles.new(token: "heading")
    expect(dup).not_to be_valid
    expect(dup.errors[:token].join).to match(/taken/i)
  end

  it "refuses a token that is not lower_snake_case" do
    expect(roles.new(token: "Heading")).not_to be_valid
    expect(roles.new(token: "collect-effect")).not_to be_valid
    expect(roles.new(token: "collect_effect2")).to be_valid
  end

  # The vocabularies are CLOSED. A lookup table that grows by typo is not one.
  it "refuses an unknown token instead of creating it, and says what is known" do
    expect { roles.fetch_token!("headding") }
      .to raise_error(ArgumentError, /not a semanticRole.*closed.*heading/m)
    expect(roles.count).to eq(14)
  end

  it "keeps declaration order rather than alphabetical" do
    expect(Mmg::Acia::Dimensions::LayoutArity.ordered.pluck(:token)).to eq(%w[one two three many])
  end

  it "records the registry version the vocabulary came from" do
    expect(roles.for_token("heading").registry_version).to eq("ghis-19@1")
  end

  it "has no dimension_key on the abstract base, since it has no table" do
    expect { described_class.dimension_key }.to raise_error(NotImplementedError)
  end
end
