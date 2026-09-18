# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "yaml"

RSpec.describe "SIC OKF bundle" do
  it "imports the sibling stewardship-intelligence-cloud docs tree" do
    skip "SIC docs not present at #{sic_docs}" unless File.directory?(sic_docs)

    result = Vv::PerSite::Okf::Importer.import(sic_docs)
    expect(result[:ok]).to eq(true), result.inspect
    expect(result[:created]).to be > 5

    root = Vv::PerSite::OkfNode.roots.first
    expect(root.kind).to eq("bundle")
    expect(root.okf_version).to eq("0.2")
    expect(root.title).to include("Stewardship Intelligence")

    expect(Vv::PerSite::OkfNode.find_by(okf_path: "from_human/vision.md")).not_to be_nil
    expect(Vv::PerSite::OkfNode.find_by(okf_path: "generated/personas.md")).not_to be_nil
    expect(Vv::PerSite::OkfNode.cta_leaves.count).to be > 0
    expect(Vv::PerSite::OkfNode.cta_leaves.map(&:title)).to include("2. The Builder")
  end

  it "converts SIC docs/ into data/seed/docs YAML that reloads" do
    skip "SIC docs not present at #{sic_docs}" unless File.directory?(sic_docs)

    Dir.mktmpdir("sic-seed") do |dir|
      seed = File.join(dir, "data/seed/docs")
      result = Vv::PerSite.sync(docs_root: sic_docs, seed_root: seed)
      expect(result[:ok]).to eq(true), result.inspect
      expect(File.exist?(File.join(seed, "_manifest.yml"))).to eq(true)
      expect(File.exist?(File.join(seed, "from_human/vision.yml"))).to eq(true)
      yaml = YAML.safe_load(File.read(File.join(seed, "from_human/vision.yml")))
      expect(yaml["title"]).to include("Stewardship Intelligence")
      expect(Vv::PerSite::OkfNode.find_by(okf_path: "from_human/foundations.md").kind).to eq("document")
    end
  end
end
