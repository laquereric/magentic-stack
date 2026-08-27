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
    # something else (ADR 0003, now ADR 0035).
    %w[semanticRole contentRole layoutKind layoutArity behaviorKind].each do |pred|
      expect(result[:triples].grep(/#{pred}/)).not_to be_empty, "missing #{pred}"
    end
  end

  # THE TUPLE IS A NODE, and its values are terms in the specified vocabulary.
  #
  # ux:ComponentShape says `ux:slt sh:class ux:SLTTuple`, so the five dimensions
  # hang off the tuple, not off the component.
  it "emits the SLT tuple as its own typed node" do
    slt_edges = result[:triples].grep(%r{<https://w3id.org/cpcp/osi8/ux#slt> })
    tuples = result[:triples].grep(%r{<https://w3id.org/cpcp/osi8/ux#SLTTuple> \.$})

    expect(slt_edges.size).to eq(result[:nodes])
    expect(tuples.size).to eq(result[:nodes])
  end

  it "hangs each dimension off the TUPLE, never off the component" do
    dims = result[:triples].grep(%r{<https://w3id.org/cpcp/osi8/ux#(semanticRole|contentRole|layoutKind|layoutArity|behaviorKind)>})

    expect(dims).not_to be_empty
    dims.each do |t|
      expect(t).to match(%r{\A<[^>]+/slt> }), "dimension is on the component, not the tuple: #{t}"
    end
  end

  # ux:heading -- the term the specification defines, not a name of our own that
  # merely agrees in spelling.
  it "uses the specification's own term IRIs" do
    expect(result[:triples]).to include(
      a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#semanticRole> <https://w3id.org/cpcp/osi8/ux#\w+> \.})
    )
    expect(result[:triples].grep(%r{urn:mm:vocab/acia\#(semanticRole|contentRole|layoutKind)})).to be_empty
  end

  # ux:SLTTupleShape is sh:closed with seven required properties, so a tuple that
  # carries only the five dimensions does not conform.
  it "completes the closed tuple shape" do
    expect(result[:triples]).to include(a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#responsiveSignature> "}))
    expect(result[:triples]).to include(a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#tokenSignature> <}))
  end

  # THE PROP TABLE IS GONE, and that is conformance rather than loss.
  #
  # It put one predicate per key straight onto the component. ux:ComponentShape
  # is sh:closed and has no slot for them, so every prop was a violation. The
  # values live in ux:props -> TypedProps -> valueJson, which is where the shape
  # says they live.
  it "carries props as a TypedProps node, not as predicates on the component" do
    expect(result[:triples]).to include(a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#props> <}))
    expect(result[:triples]).to include(a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#TypedProps> \.}))
    expect(result[:triples]).to include(a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#valueJson> "}))
    expect(result[:triples].grep(%r{acia/prop\#})).to be_empty
  end

  it "carries the variant as a VariantSelection node" do
    expect(result[:triples]).to include(a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#VariantSelection> \.}))
    expect(result[:triples]).to include(
      a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#variantName> <https://w3id.org/cpcp/osi8/ux#\w+>})
    )
  end

  # CONTAINMENT RUNS PARENT -> CHILD. The shape models ux:child; the ux:parent
  # edge this used to assert has no slot in it.
  it "carries containment as child edges, one per non-root node" do
    children = result[:triples].grep(%r{<https://w3id.org/cpcp/osi8/ux#child>})

    expect(children.size).to eq(result[:nodes] - 1)
    expect(result[:triples].grep(%r{<https://w3id.org/cpcp/osi8/ux#parent>})).to be_empty
  end

  it "lands in its own graph, not the SAL one" do
    expect(result[:graph]).to eq("urn:mm:graph:acia:profile9")
    expect(result[:graph]).not_to include("sal")
  end

  # The document points at its root; nodes no longer point back at the document.
  # ux:AciaDocumentShape is closed over rootNode, and ux:inDocument is not in it.
  it "binds the document to its root, and stamps every node with the digest" do
    expect(result[:document]).to include(result[:digest].sub("sha256:", ""))
    expect(result[:triples]).to include(a_string_matching(%r{<https://w3id.org/cpcp/osi8/ux#rootNode> <}))
    expect(result[:triples].grep(%r{<https://w3id.org/cpcp/osi8/ux#inDocument>})).to be_empty

    digests = result[:triples].grep(%r{<https://w3id.org/cpcp/osi8/ux#digest> "#{result[:digest]}"})
    expect(digests.size).to eq(result[:nodes] + 1) # every node, and the document
  end

  # GovernedFieldsShape is sh:and-ed into every governed shape, so a node without
  # these is not a Profile 9 node at all.
  it "stamps every node with the governed fields" do
    %w[cid digest profileId ledgerPlacement].each do |f|
      expect(result[:triples].grep(%r{<https://w3id.org/cpcp/osi8/ux##{f}>}).size).to be >= result[:nodes]
    end
    expect(result[:triples]).to include(a_string_matching(%r{<http://purl.org/dc/terms/created>}))
    expect(result[:triples]).to include(a_string_matching(%r{<http://www.w3.org/ns/prov\#wasGeneratedBy>}))
  end

  # A document the profile has already refused has no digest to project, and
  # projecting it anyway produced triples claiming governance they did not have.
  it "refuses to project a document that does not validate" do
    out = PJ.triples({ "schemaVersion" => "acia/v1",
                                    "root" => { "nodeId" => "x", "componentKind" => "PageShell" } })
    expect(out[:ok]).to be(false)
    expect(out[:reason]).to eq(:acia_invalid)
  end

  it "ESCAPES what boards actually contain" do
    # A refusal notice carries prose with quotes in it. One unescaped quote makes
    # the store reject the whole payload, so the failure is never the triple that
    # was wrong. The prose now travels inside valueJson rather than as its own
    # predicate, which is more escaping, not less: JSON quoting inside N-Triples
    # quoting.
    nasty = Marshal.load(Marshal.dump(doc))
    nasty["root"]["props"]["valueJson"]["title"] = %(a "quoted" line\nand a newline\tand a tab)

    out = PJ.triples(nasty)
    expect(out[:ok]).to be(true)

    line = out[:triples].grep(%r{valueJson}).first
    expect(line).not_to be_nil
    expect(line).not_to include("\n")
    expect(line).not_to include("\t")
    # every quote in the object position is escaped, so the line still parses
    expect(line.scan(/(?<!\\)"/).size).to eq(2)
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
