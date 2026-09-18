# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "yaml"

RSpec.describe Vv::PerSite::Okf::Seeder do
  it "writes Rails-shaped YAML under data/seed/docs and reloads it into AR" do
    Dir.mktmpdir("vv-per-site-seed") do |dir|
      seed = File.join(dir, "data/seed/docs")
      exported = described_class.export(fixture_docs, seed)
      expect(exported).to include(ok: true)
      expect(File.exist?(File.join(seed, "_manifest.yml"))).to eq(true)
      expect(File.exist?(File.join(seed, "index.yml"))).to eq(true)
      expect(File.exist?(File.join(seed, "from_human/_folder.yml"))).to eq(true)
      expect(File.exist?(File.join(seed, "from_human/vision.yml"))).to eq(true)
      expect(File.exist?(File.join(seed, "generated/personas/the-builder.yml"))).to eq(true)

      vision = YAML.safe_load(File.read(File.join(seed, "from_human/vision.yml")), permitted_classes: [Date, Time])
      expect(vision["okf_path"]).to eq("from_human/vision.md")
      expect(vision["parent_okf_path"]).to eq("from_human")
      expect(vision["kind"]).to eq("document")
      expect(vision["title"]).to eq("Fixture Vision")
      expect(vision["body"]).to include("Awareness precedes action")

      loaded = described_class.load!(seed)
      expect(loaded).to include(ok: true)
      expect(Vv::PerSite::OkfNode.find_by(okf_path: "generated/personas.md#the-builder").kind).to eq("cta_leaf")
    end
  end

  it "syncs docs → seed YAML → AR in one call" do
    Dir.mktmpdir("vv-per-site-sync") do |dir|
      seed = File.join(dir, "data/seed/docs")
      result = described_class.sync(fixture_docs, seed)
      expect(result[:ok]).to eq(true), result.inspect
      expect(result[:exported][:files]).to be > 1
      expect(result[:loaded][:created]).to be > 0
    end
  end
end
