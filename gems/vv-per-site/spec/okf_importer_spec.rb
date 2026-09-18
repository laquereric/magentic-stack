# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::PerSite::Okf::Importer do
  it "upserts the fixture tree as an ancestry hierarchy" do
    result = described_class.import(fixture_docs)
    expect(result).to include(ok: true)
    expect(result[:created]).to be > 0

    root = Vv::PerSite::OkfNode.roots.first
    expect(root.okf_path).to eq("index.md")
    expect(root.kind).to eq("bundle")
    expect(root.children.map(&:okf_path)).to include("from_human", "generated")

    vision = Vv::PerSite::OkfNode.find_by!(okf_path: "from_human/vision.md")
    expect(vision.parent.okf_path).to eq("from_human")
    expect(vision.doc_type).to eq("Vision")
    expect(vision.tags).to include("vision")
    expect(vision.generated_by).to eq("human:lamont-wheat")

    builder = Vv::PerSite::OkfNode.find_by!(okf_path: "generated/personas.md#the-builder")
    expect(builder.kind).to eq("cta_leaf")
    expect(builder.ancestors.map(&:okf_path)).to eq(["index.md", "generated", "generated/personas.md"])
  end

  it "is idempotent on a second import" do
    described_class.import(fixture_docs)
    second = described_class.import(fixture_docs)
    expect(second).to include(ok: true)
    expect(second[:created]).to eq(0)
    expect(second[:updated]).to be > 0
    expect(Vv::PerSite::OkfNode.where(okf_path: "index.md").count).to eq(1)
  end
end
