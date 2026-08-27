# frozen_string_literal: true
require "spec_helper"
require "mmg/acia/cognition_projection"

RSpec.describe Mmg::Acia::CognitionProjection do
  P2 = "https://w3id.org/laquereric/cpcp/ps1-p2/ns#"
  CPCP = "https://w3id.org/laquereric/cpcp/ns#"

  def node(**over)
    { id: 7, entity_iri: "urn:mm:arc:arc/2026-07-11-flow", value: "arc_flow_run_show" }.merge(over)
  end

  it "emits a Preview naming the handle a model can dereference" do
    t = described_class.preview_triples(node)

    expect(t).to include("<urn:mmg:sal:acia:7/preview> <#{CPCP}references> <urn:mm:arc:arc/2026-07-11-flow> .")
    expect(t).to include(a_string_matching(%r{<#{P2}Preview> \.}))
  end

  # p2:PreviewShape is closed over previewText + references, and references is
  # minCount 1. A preview with no referent is not a preview.
  it "emits NO preview for a node with no referent" do
    expect(described_class.preview_triples(node(entity_iri: nil))).to be_empty
    expect(described_class.preview_triples(node(entity_iri: ""))).to be_empty
  end

  # cpcp:references is sh:nodeKind sh:IRI -- a bare token parses and means nothing.
  it "refuses a referent that is not an IRI" do
    expect(described_class.preview_triples(node(entity_iri: "arc_flow_run_show"))).to be_empty
  end

  # THE POINT OF THE SPLIT: what a model reads is not always what the pane shows.
  it "prefers preview_text over the visible value" do
    t = described_class.preview_triples(node(preview_text: "Shows a run of the arc flow coordinator."))

    expect(t).to include(a_string_matching(/previewText> "Shows a run/))
    expect(t).not_to include(a_string_matching(/previewText> "arc_flow_run_show"/))
  end

  it "falls back to the visible value when a node has nothing further to say" do
    expect(described_class.preview_triples(node))
      .to include(a_string_matching(/previewText> "arc_flow_run_show"/))
  end

  describe "insight" do
    it "summarises a subtree and references every handle in it" do
      root = node(id: 1, cognition_summary: "The arc flow pane.", entity_iri: "urn:mm:arc:a")
      kids = [node(id: 2, entity_iri: "urn:mm:brief:b"), node(id: 3, entity_iri: "urn:mm:repo:c")]
      t = described_class.insight_triples(root, descendants: kids)

      expect(t).to include(a_string_matching(%r{<#{CPCP}Insight> \.}))
      expect(t).to include(a_string_matching(/summary> "The arc flow pane\."/))
      expect(t.grep(%r{#{CPCP}references}).size).to eq(3)
    end

    it "emits none without a summary, since p2:summary is required" do
      expect(described_class.insight_triples(node)).to be_empty
    end

    it "skips referents that are not IRIs rather than emitting them" do
      root = node(id: 1, cognition_summary: "s", entity_iri: "urn:mm:arc:a")
      t = described_class.insight_triples(root, descendants: [node(id: 2, entity_iri: "bare-token")])
      expect(t.grep(%r{#{CPCP}references}).size).to eq(1)
    end
  end

  it "projects a whole tree: a preview per referring node, plus the root insight" do
    root = node(id: 1, cognition_summary: "The pane.", entity_iri: "urn:mm:arc:a")
    kids = [node(id: 2, entity_iri: "urn:mm:brief:b"), node(id: 3, entity_iri: nil)]
    t = described_class.tree_triples(root, descendants: kids)

    expect(t.grep(%r{<#{P2}Preview> \.}).size).to eq(2)  # the node with no referent makes none
    expect(t.grep(%r{<#{CPCP}Insight> \.}).size).to eq(1)
  end

  it "escapes prose, which is what a preview mostly is" do
    t = described_class.preview_triples(node(preview_text: %(a "quoted" line\nand a newline)))
    line = t.grep(/previewText/).first

    expect(line).to include('\\"quoted\\"')
    expect(line).not_to include("\n")
  end
end
