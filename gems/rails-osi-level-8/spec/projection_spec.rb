# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ACIA as triples" do
  PJ = RailsOsiLevel8::Profile9::Projection
  AA = RailsOsiLevel8::Profile9::Acia
  RD = RailsOsiLevel8::Profile9::Renderer
  TK = { "tokens" => { "setRef" => "tokens:ghis@1" } }.freeze

  let(:doc) { AA.translation_board_document }
  let(:result) { PJ.triples(doc) }

  it "projects every node in the tree" do
    expect(result[:ok]).to be(true)
    count = 0
    walk = lambda { |n| next unless n.is_a?(Hash); count += 1; Array(n["children"]).each { |c| walk.call(c) } }
    walk.call(doc["root"])
    expect(result[:nodes]).to eq(count)
  end

  it "NAMES THE SAME THING THE RENDERED ELEMENT DOES" do
    # The whole point of projecting. The first cut hashed the node itself and
    # produced valid triples naming things no element carried -- a graph that
    # looks joinable to the DOM and is not.
    html = RD.render(acia: doc, token_set: TK, correlation: "cid:page:spec")["html"]
    dom_cids = html.scan(/data-ux-node-cid="cid:node:([0-9a-f]+)"/).flatten.uniq
    graph_ids = result[:triples]
                .grep(%r{<urn:mm:acia:node:([0-9a-f]+)>})
                .map { |t| t[%r{urn:mm:acia:node:([0-9a-f]+)}, 1] }.uniq

    expect(dom_cids).not_to be_empty
    expect(graph_ids).to match_array(dom_cids)
  end

  it "gives the SLT tuple five predicates of its own" do
    # Not folded into semantic_role: Mmg::Acia has one of those and it means
    # something else (ADR 0003).
    %w[semanticRole contentRole layoutKind layoutArity behaviorKind].each do |pred|
      expect(result[:triples].grep(/#{pred}/)).not_to be_empty, "missing #{pred}"
    end
  end

  it "keeps the prop table queryable, one predicate per key" do
    expect(result[:triples]).to include(
      a_string_matching(%r{<urn:mm:vocab/acia/prop#title> "Translation Board"})
    )
  end

  it "carries the parent edge, so the tree survives as a graph" do
    parents = result[:triples].grep(%r{<urn:mm:vocab/acia#parent>})
    # every node but the root
    expect(parents.size).to eq(result[:nodes] - 1)
  end

  it "lands in its own graph, not the SAL one" do
    expect(result[:graph]).to eq("urn:mm:graph:acia:profile9")
    expect(result[:graph]).not_to include("sal")
  end

  it "binds every node to the document digest" do
    expect(result[:document]).to include(result[:digest].sub("sha256:", ""))
    in_doc = result[:triples].grep(%r{<urn:mm:vocab/acia#inDocument>})
    expect(in_doc.size).to eq(result[:nodes])
  end

  it "ESCAPES what boards actually contain" do
    # A refusal notice carries prose with quotes in it. One unescaped quote
    # makes the store reject the whole payload, so the failure is never the
    # triple that was wrong.
    nasty = { "schemaVersion" => "acia/v1", "componentRegistryVersion" => "ghis-19@1",
              "root" => { "nodeId" => "n1", "componentKind" => "SemanticText",
                          "slt" => { "semanticRole" => "article" },
                          "props" => { "valueJson" => {
                            "title" => %(a "quoted" line\nand a newline\tand a tab) } } } }
    out = PJ.triples(nasty)
    line = out[:triples].grep(%r{prop#title}).first
    expect(line).to include('\\"quoted\\"')
    expect(line).to include('\\n')
    expect(line).not_to include("\n")
  end

  it "refuses a document with no root rather than projecting nothing" do
    r = PJ.triples({ "schemaVersion" => "acia/v1" })
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:no_root)
  end

  it "never raises, whatever it is handed" do
    [nil, 42, "", [], { "root" => "not a hash" }].each do |junk|
      expect { PJ.triples(junk) }.not_to raise_error
    end
  end

  it "is stable: the same document projects the same triples" do
    expect(PJ.triples(doc)[:triples]).to eq(result[:triples])
  end

  it "changes when the document changes" do
    other = AA.translation_board_document(
      composed: [{ "canonicalId" => "Y4", "title" => "T", "label" => "Y4 — T", "body" => "" }]
    )
    expect(PJ.triples(other)[:digest]).not_to eq(result[:digest])
  end
end
