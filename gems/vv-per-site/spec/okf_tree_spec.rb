# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::PerSite::Okf::Tree do
  it "walks a docs folder into a parent-before-child node list" do
    walked = described_class.walk(fixture_docs)
    expect(walked[:ok]).to eq(true)
    expect(walked[:bundle_key]).to eq("fixture-stewardship")
    paths = walked[:nodes].map { |n| n["okf_path"] }
    expect(paths.first).to eq("index.md")
    expect(paths).to include("from_human", "from_human/vision.md", "generated/personas.md")
    expect(paths).to include("generated/personas.md#the-builder")
    index = walked[:nodes].first
    expect(index["kind"]).to eq("bundle")
    expect(index["okf_version"]).to eq("0.2")
    builder = walked[:nodes].find { |n| n["okf_path"] == "generated/personas.md#the-builder" }
    expect(builder["kind"]).to eq("cta_leaf")
    expect(builder["parent_okf_path"]).to eq("generated/personas.md")
  end
end
