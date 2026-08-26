# frozen_string_literal: true
require "ar_spec_helper"

RSpec.describe Mmg::Acia::Node, "the five SLT relations" do
  let(:slt) do
    { "semanticRole" => "heading", "contentRole" => "context", "layoutKind" => "stack",
      "layoutArity" => "one", "behaviorKind" => "static" }
  end

  def node(**over)
    described_class.create!({ tree_key: "t", kind: "text", value: "v", position: 0 }.merge(over))
  end

  it "resolves an SLT tuple to five rows" do
    n = node(**described_class.slt_attributes(slt))

    expect(n.slt_semantic_role.token).to eq("heading")
    expect(n.content_role.token).to eq("context")
    expect(n.layout_kind.token).to eq("stack")
    expect(n.layout_arity.token).to eq("one")
    expect(n.behavior_kind.token).to eq("static")
  end

  it "reads the tuple back in Profile 9's shape" do
    expect(node(**described_class.slt_attributes(slt)).slt).to eq(slt)
  end

  # 62 of 81 live nodes carry no role at all. A required dimension would force
  # inventing one, and an invented dimension reads as a decision somebody made.
  it "leaves every dimension optional" do
    n = node

    expect(n).to be_persisted
    expect(n.slt_semantic_role).to be_nil
    expect(n.slt).to eq({})
  end

  it "omits an absent dimension rather than reporting it blank" do
    n = node(**described_class.slt_attributes(slt.except("behaviorKind")))
    expect(n.slt.keys).not_to include("behaviorKind")
  end

  # THE COLLISION. semantic_role holds the DOMAIN role and is read as a string
  # across a dozen gems; slt_semantic_role holds the WIDGET role. If the
  # association shadowed the attribute, every one of those readers would break.
  it "does not shadow the existing semantic_role string attribute" do
    n = node(semantic_role: "arc", **described_class.slt_attributes(slt))

    expect(n.semantic_role).to eq("arc")
    expect(n.semantic_role).to be_a(String)
    expect(n.slt_semantic_role).to be_a(Mmg::Acia::Dimensions::SemanticRole)
  end

  it "refuses an unknown SLT token instead of inventing a row" do
    expect { described_class.slt_attributes(slt.merge("layoutKind" => "waterfall")) }
      .to raise_error(ArgumentError, /not a layoutKind/)
    expect(Mmg::Acia::Dimensions::LayoutKind.count).to eq(7)
  end

  describe "materialize" do
    it "carries an SLT tuple from a render-tree node onto the row" do
      root = described_class.materialize(
        { kind: "text", value: "hello", slt: slt, children: [] }, tree_key: "mat"
      )
      expect(root.slt).to eq(slt)
    end

    it "still materializes a node with no SLT at all" do
      root = described_class.materialize({ kind: "text", value: "x" }, tree_key: "mat2")
      expect(root).to be_persisted
      expect(root.slt).to eq({})
    end
  end

  describe "graph conformance" do
    # WHICH PATH THIS EXERCISES. vv-graph is not in this gem's test bundle, so
    # Vv::Graph::TripleModel is unmounted and to_triples takes the FALLBACK
    # branch. Both branches emit the same five predicates by construction (they
    # share SLT_RELATIONS and SLT_KEY_FOR), but only this one is executed here --
    # stated so the coverage is not read as wider than it is.
    it "is exercising the TripleModel-unmounted path" do
      expect(defined?(::Vv::Graph::TripleModel)).to be_nil
    end

    it "emits each dimension as an IRI, not a repeated literal" do
      n = node(**described_class.slt_attributes(slt))
      t = n.to_triples

      expect(t).to include("<#{n.iri}> <urn:mm:vocab/acia#semanticRole> <urn:mm:vocab/acia#semanticRole/heading> .")
      expect(t).to include("<#{n.iri}> <urn:mm:vocab/acia#layoutKind> <urn:mm:vocab/acia#layoutKind/stack> .")
      expect(t.grep(%r{<urn:mm:vocab/acia#(semanticRole|contentRole|layoutKind|layoutArity|behaviorKind)>}).size).to eq(5)
    end

    # Additive. Nothing already in urn:mmg:sal:public needs rewriting.
    it "still emits every pre-existing triple" do
      n = node(semantic_role: "arc", sal_component: "c", entity_iri: "urn:x",
               **described_class.slt_attributes(slt))
      t = n.to_triples

      expect(t).to include(%(<#{n.iri}> <urn:mm:grammar:sal#role> "arc" .))
      expect(t).to include(%(<#{n.iri}> <urn:mm:grammar:sal#kind> "text" .))
      expect(t).to include(%(<#{n.iri}> <urn:mm:grammar:sal#entityIri> "urn:x" .))
      expect(t.grep(/22-rdf-syntax-ns#type/)).not_to be_empty
    end

    it "emits no dimension triple for a node that has none" do
      t = node.to_triples
      expect(t.grep(%r{<urn:mm:vocab/acia#semanticRole>})).to be_empty
    end
  end
end

RSpec.describe Mmg::Acia::Node, "against a schema that has not run the migration" do
  # The substrate is pinned behind this gem, so "new code, old schema" is a real
  # state a consumer can be in between a repin and db:migrate. Materializing must
  # still work, and an SLT tuple must be DROPPED rather than faked -- storing a
  # node that claims a vocabulary the schema cannot hold would be worse than
  # ignoring it.
  before { allow(described_class).to receive(:column_names).and_return(described_class.column_names - ["slt_semantic_role_id"]) }

  it "still materializes a plain node" do
    n = described_class.materialize({ kind: "text", value: "hi", semantic_role: "arc" }, tree_key: "old")

    expect(n).to be_persisted
    expect(n.semantic_role).to eq("arc")
  end

  it "drops an SLT tuple instead of raising or faking it" do
    n = described_class.materialize(
      { kind: "text", value: "x", slt: { "semanticRole" => "heading" } }, tree_key: "old2"
    )

    expect(n).to be_persisted
    expect(n.slt).to eq({})
    expect(n.to_triples.grep(%r{<urn:mm:vocab/acia#semanticRole>})).to be_empty
  end
end

RSpec.describe Mmg::Acia::Node, "conformance with the Profile 9 graph vocabulary" do
  TYPE_P = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  def node(**over)
    described_class.create!({ tree_key: "t", kind: "text", value: "v", position: 3 }.merge(over))
  end

  # A query written against Profile 9's vocabulary should see substrate nodes.
  it "types the node as the Profile 9 node class" do
    n = node
    expect(n.to_triples).to include("<#{n.iri}> <#{TYPE_P}> <urn:mm:vocab/acia#Node> .")
  end

  # BOTH typings are true, and dropping the SAL one would lose a real statement:
  # urn:mm:vocab/sal# is the SAL CLASS namespace -- Behavior, Platform, Shape and
  # Style live there too, so it is not a stray to be tidied away.
  it "keeps the SAL typing alongside it" do
    t = node.to_triples
    expect(t.grep(%r{vocab/sal#AciaNode})).not_to be_empty
    expect(t.grep(%r{vocab/acia#Node})).not_to be_empty
  end

  it "emits the two structural predicates Profile 9 names" do
    parent = node
    child = node(parent: parent, position: 1)
    t = child.to_triples

    expect(t).to include("<#{child.iri}> <urn:mm:vocab/acia#parent> <#{parent.iri}> .")
    expect(t).to include(%(<#{child.iri}> <urn:mm:vocab/acia#position> "1" .))
  end

  # The SAL grammar keeps its own names. mmg-sal reads grammar:sal# for
  # action / kind / role / props / children; renaming that namespace wholesale
  # would break five of its models and three SHACL files to make two
  # vocabularies look like one.
  it "leaves the SAL grammar predicates exactly where they were" do
    t = node(semantic_role: "arc", sal_component: "c", entity_iri: "urn:x").to_triples

    expect(t.grep(%r{grammar:sal#kind})).not_to be_empty
    expect(t.grep(%r{grammar:sal#role})).not_to be_empty
    expect(t.grep(%r{grammar:sal#component})).not_to be_empty
    expect(t.grep(%r{grammar:sal#entityIri})).not_to be_empty
  end
end

RSpec.describe Mmg::Acia::Node, "destroy under optimistic locking" do
  def tree(key)
    root = described_class.create!(tree_key: key, kind: "pane", value: "r", position: 0)
    kid = described_class.create!(tree_key: key, kind: "text", value: "k", position: 0, parent: root)
    described_class.create!(tree_key: key, kind: "text", value: "g", position: 0, parent: kid)
    root
  end

  # ancestry's orphan_strategy: :destroy removes the descendants when the root
  # goes, so destroy_all's loop then reaches instances whose rows are already
  # gone. Optimistic locking cannot tell that from a concurrent update and used
  # to raise -- AFTER every row had in fact been deleted.
  it "destroys a whole tree without raising on the rows the cascade already took" do
    tree("t1")
    expect(described_class.where(tree_key: "t1").count).to eq(3)

    expect { described_class.where(tree_key: "t1").destroy_all }.not_to raise_error
    expect(described_class.where(tree_key: "t1").count).to eq(0)
  end

  it "marks the already-cascaded instance destroyed, as ActiveRecord would" do
    root = tree("t2")
    kid = root.children.first
    root.destroy

    expect { kid.destroy }.not_to raise_error
    expect(kid).to be_destroyed
    expect(kid).to be_frozen
  end

  # THE PART THAT MUST NOT BE SWALLOWED. If the row is still there, the lock
  # version genuinely moved under us and that is a real conflict.
  it "still raises when the row exists and the lock version moved" do
    n = described_class.create!(tree_key: "t3", kind: "text", value: "v", position: 0)
    stale = described_class.find(n.id)
    n.update!(value: "changed")

    expect { stale.destroy }.to raise_error(ActiveRecord::StaleObjectError)
    expect(described_class.exists?(n.id)).to be(true)
  end

  it "destroys normally when nothing is stale" do
    n = described_class.create!(tree_key: "t4", kind: "text", value: "v", position: 0)
    expect { n.destroy }.not_to raise_error
    expect(described_class.exists?(n.id)).to be(false)
  end
end
