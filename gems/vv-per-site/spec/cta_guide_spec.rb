# frozen_string_literal: true

require "spec_helper"

RSpec.describe "per-site CTA guide" do
  before do
    Vv::PerSite::Okf::Importer.import(fixture_docs)
  end

  it "does not define the host ApplicationRecord" do
    expect(defined?(::ApplicationRecord)).to be_nil
    expect(Vv::PerSite::OkfNode.superclass).to eq(Vv::PerSite::Record)
    expect(Vv::PerSite::Record.abstract_class).to eq(true)
  end

  it "lets a particular site register a CTA on a leaf and walk the questions" do
    site = Vv::PerSite::Site.create!(
      key: "wheat-stewardship",
      name: "Wheat Stewardship",
      host: "wheat.example",
      bundle_key: "fixture-stewardship"
    )
    leaf = Vv::PerSite::OkfNode.find_by!(okf_path: "generated/personas.md#the-builder")
    cta = site.ctas.create!(
      okf_node: leaf,
      key: "builder-primer",
      title: "Request the technical primer",
      action_kind: "calendar",
      payload: { "event" => "discovery" }
    )
    expect(cta.payload).to eq("event" => "discovery")

    guide = site.guide
    root = guide.root
    expect(root[:ok]).to eq(true)
    expect(root[:node].okf_path).to eq("index.md")
    expect(root[:options].map { |o| o[:path] }).to include("generated", "from_human")
    expect(root[:cta]).to be_nil

    generated = guide.choose("index.md", "generated")
    expect(generated[:ok]).to eq(true)

    at_leaf = guide.at("generated/personas.md#the-builder")
    expect(at_leaf[:ok]).to eq(true)
    expect(at_leaf[:cta]).to eq(cta)
    expect(at_leaf[:cta].title).to eq("Request the technical primer")
  end

  it "refuses a choice that is not a child" do
    site = Vv::PerSite::Site.create!(
      key: "other",
      name: "Other",
      bundle_key: "fixture-stewardship"
    )
    r = site.guide.choose("index.md", "nope")
    expect(r).to include(ok: false, reason: :not_a_child)
  end
end
