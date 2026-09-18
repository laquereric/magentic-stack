# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::PerSite::Okf::Parser do
  it "reads OKF v0.2 frontmatter and the markdown body" do
    parsed = described_class.parse(File.read(File.join(fixture_docs, "from_human/vision.md")))
    expect(parsed[:title]).to eq("Fixture Vision")
    expect(parsed[:doc_type]).to eq("Vision")
    expect(parsed[:okf_version]).to eq("")
    expect(parsed[:tags]).to include("vision")
    expect(parsed[:generated_by]).to eq("human:lamont-wheat")
    expect(parsed[:body]).to include("Awareness precedes action")
    expect(parsed[:frontmatter]["status"]).to eq("stable")
  end

  it "reads okf_version from the bundle index" do
    parsed = described_class.parse(File.read(File.join(fixture_docs, "index.md")))
    expect(parsed[:okf_version]).to eq("0.2")
    expect(parsed[:title]).to eq("Fixture Stewardship")
  end

  it "splits ATX headings into sections and flags CTA leaves" do
    parsed = described_class.parse(File.read(File.join(fixture_docs, "generated/personas.md")))
    sections = described_class.sections(parsed[:body])
    expect(sections.map { |s| s[:title] }).to eq(["The Builder", "The Community Steward"])
    builder = sections.find { |s| s[:title] == "The Builder" }
    expect(builder[:cta_leaf]).to eq(true)
    expect(builder[:slug]).to eq("the-builder")
  end
end
