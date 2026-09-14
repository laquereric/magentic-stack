# frozen_string_literal: true

# GATE: `declares` and `references` stay disjoint.
#
# The declaration is where you change a version; the references are what you
# must re-check BECAUSE it changed. Collapse them and the reverse query loses
# the set a reviewer needs -- and loses it invisibly, because the merged list
# still looks like an answer.
RSpec.describe Vv::DependencyOrch::Graph do
  subject(:graph) { described_class.new }

  let(:floor) { "sha256:#{'8' * 64}" }

  let(:declaration) do
    Vv::DependencyOrch::Edge.new(
      kind: :declares, from: "line:magentic-stack/runtimes/rails-base/FLOOR.json#L12", to: floor,
      where: { repo: "magentic-stack", path: "runtimes/rails-base/FLOOR.json", line: 12 }
    )
  end

  let(:reference) do
    Vv::DependencyOrch::Edge.new(
      kind: :references, from: "line:vv-canvas/Dockerfile.thin#L1", to: floor,
      where: { repo: "vv-canvas", path: "Dockerfile.thin", line: 1 }
    )
  end

  before do
    graph.add_resource(Vv::DependencyOrch::Resource.new(digest: floor, kind: :remote, names: ["rails-base"]))
    graph.add_edge(declaration)
    graph.add_edge(reference)
  end

  it "returns the two sets apart" do
    expect(graph.declares_of(floor)).to eq([declaration])
    expect(graph.references_of(floor)).to eq([reference])
  end

  it "puts nothing in both sets" do
    expect(graph.declares_of(floor) & graph.references_of(floor)).to be_empty
  end

  # PLANT: the union that must not exist. If someone adds a merged accessor,
  # this is the test that says why they should not have.
  it "offers no merged accessor" do
    expect(graph).not_to respond_to(:pin_edges)
    expect(graph).not_to respond_to(:all_pin_edges)
  end

  it "names the disjoint pair on the Edge class rather than in a comment" do
    expect(Vv::DependencyOrch::Edge::DISJOINT).to contain_exactly(:declares, :references)
  end

  describe "#resolve" do
    it "finds a resource by its full digest" do
      expect(graph.resolve(floor)[:resource].digest).to eq(floor)
    end

    it "finds a resource by a digest prefix a human typed" do
      expect(graph.resolve(floor[0, 20])[:resource].digest).to eq(floor)
    end

    it "finds a resource by an observed name" do
      expect(graph.resolve("rails-base")[:resource].digest).to eq(floor)
    end

    # PLANT: a tag reaching the lookup must keep its own refusal, not be
    # rewritten as "not found" -- the mistake is not that we could not find it,
    # it is that it was never a key.
    it "passes a tag refusal through unchanged" do
      expect(graph.resolve("rails-base:latest")).to include(reason: "tag_is_not_identity")
    end

    it "refuses rather than picking when a name matches two digests" do
      other = "sha256:#{'9' * 64}"
      graph.add_resource(Vv::DependencyOrch::Resource.new(digest: other, kind: :remote, names: ["rails-base"]))

      result = graph.resolve("rails-base")
      expect(result[:ok]).to be false
      expect(result[:reason]).to eq("ambiguous_reference")
      expect(result[:because]).to match(/matches 2 digests/)
    end

    it "says no_such_resource for a well-formed digest nobody holds" do
      expect(graph.resolve("sha256:#{'f' * 64}")).to include(reason: "no_such_resource")
    end
  end

  describe "traversal" do
    it "terminates on a cycle" do
      a = "sha256:#{'a' * 64}"
      b = "sha256:#{'b' * 64}"
      graph.add_edge(Vv::DependencyOrch::Edge.new(kind: :derives_from, from: a, to: b))
      graph.add_edge(Vv::DependencyOrch::Edge.new(kind: :derives_from, from: b, to: a))

      expect { graph.forward(a, depth: 10) }.not_to raise_error
      expect(graph.forward(a, depth: 10).length).to be <= 10
    end
  end
end

RSpec.describe Vv::DependencyOrch::Resource do
  # GATE: a locally built image has no repo digest, and `false` survives.
  it "represents an unpublished local image as index_digest false" do
    resource = described_class.new(digest: "sha256:#{'e' * 64}", kind: :local, index_digest: false)

    expect(resource.unpublished?).to be true
    expect(resource.to_h).to have_key(:index_digest)
    expect(resource.to_h[:index_digest]).to be(false)
  end

  # PLANT: `false` and `nil` must not collapse. One is a fact about the world,
  # the other a fact about us.
  it "keeps 'there is none' apart from 'we did not look'" do
    none = described_class.new(digest: "sha256:#{'e' * 64}", kind: :local, index_digest: false)
    unknown = described_class.new(digest: "sha256:#{'d' * 64}", kind: :remote, index_digest: nil)

    expect(none.unpublished?).to be true
    expect(unknown.unpublished?).to be false
    expect(unknown.to_h[:index_digest]).to be_nil
  end

  it "excludes attestations from the platform count" do
    resource = described_class.new(
      digest: "sha256:#{'c' * 64}", kind: :remote,
      platforms: [{ os: "linux", architecture: "arm64", variant: nil, digest: "sha256:#{'1' * 64}" }],
      attestations: [{ digest: "sha256:#{'2' * 64}" }]
    )

    expect(resource.platform_count).to eq(1)
    expect(resource.multi_platform?).to be false
    expect(resource.to_h[:platform_count]).to eq(1)
    expect(resource.to_h[:attestations]).to eq(1)
  end

  it "refuses a kind it does not model" do
    expect { described_class.new(digest: "sha256:#{'c' * 64}", kind: :vps) }
      .to raise_error(ArgumentError, /unknown resource kind/)
  end
end
