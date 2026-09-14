# frozen_string_literal: true

# The case that motivated the whole plan, reproduced.
#
# 2026-09-13, magentic-stack: FLOOR.json moved to a LOCAL, arm64, UNPUBLISHED
# image because that was the only build carrying five new gems. The file
# documented it honestly. It was still wrong, and no gate could see it, because
# every gate checks one kind in isolation and this is a fact about an edge:
# four consumers pin the floor and none of them can pull a local image.
RSpec.describe Vv::DependencyOrch::Drift do
  let(:floor) { "sha256:#{'8db4d39f' * 8}" }

  let(:consumers) do
    [
      %w[vv-canvas Dockerfile.thin],
      %w[vv-graph Dockerfile.thin],
      %w[vv-browser Dockerfile.thin],
      %w[shapes-application Dockerfile.thin]
    ]
  end

  def graph_with(resource)
    graph = Vv::DependencyOrch::Graph.new
    graph.add_resource(resource)
    graph.add_edge(
      Vv::DependencyOrch::Edge.new(
        kind: :declares, from: "line:magentic-stack/runtimes/rails-base/FLOOR.json#L12", to: floor,
        where: { repo: "magentic-stack", path: "runtimes/rails-base/FLOOR.json", line: 12 },
        because: "the declared floor"
      )
    )
    consumers.each_with_index do |(repo, path), i|
      graph.add_edge(
        Vv::DependencyOrch::Edge.new(
          kind: :references, from: "line:#{repo}/#{path}#L#{i + 1}", to: floor,
          where: { repo: repo, path: path, line: i + 1 },
          because: "digest-pinned image"
        )
      )
    end
    graph
  end

  # S4's acceptance, word for word: declared local/arm64, no reachable
  # placement for a named consumer -> ONE finding, with the consumer named.
  context "the floor case" do
    let(:resource) do
      r = Vv::DependencyOrch::Resource.new(
        digest: floor, kind: :local, names: ["rails-base"], index_digest: false,
        meta: { platform: "linux/arm64", built_locally: true }
      )
      r.observe(Vv::DependencyOrch::Placement.present(kind: :local_daemon, at: "local"))
      r
    end

    let(:result) { described_class.call(graph_with(resource)) }

    it "produces exactly one finding" do
      expect(result[:ok]).to be true
      expect(result[:findings].length).to eq(1)
      expect(result[:findings].first[:finding]).to eq(:unpublished_but_referenced)
    end

    # A finding without its consumers is a report. A finding WITH them is a work
    # list, which is the thing an operator can act on.
    it "names all four consumers" do
      referenced = result[:findings].first[:referenced_by]
      expect(referenced.length).to eq(4)
      expect(referenced.map { |c| c[:repo] })
        .to contain_exactly("vv-canvas", "vv-graph", "vv-browser", "shapes-application")
    end

    it "keeps the declaration apart from the references in the finding" do
      finding = result[:findings].first
      expect(finding[:declared_at].length).to eq(1)
      expect(finding[:declared_at].first[:path]).to eq("runtimes/rails-base/FLOOR.json")
      expect(finding[:declared_at].map { |c| c[:repo] } & finding[:referenced_by].map { |c| c[:repo] })
        .to be_empty
    end

    # The arm64/amd64 half of the story. Platform is CONTEXT on the finding
    # rather than the trigger -- an overlay built against it on an amd64 host
    # fails with "no match for platform in manifest", which reads like a bad
    # digest and is not one, so the platform has to be in front of whoever
    # reads this.
    it "carries the platform so the amd64 failure is legible" do
      expect(result[:findings].first[:platform]).to eq("linux/arm64")
    end

    # It IS present locally. That is exactly why the naive check passes and the
    # consumers still cannot pull it.
    it "fires even though the image is present in the local daemon" do
      expect(resource.reachable_placements).not_to be_empty
      expect(result[:findings]).not_to be_empty
    end
  end

  context "when every placement we reached said no" do
    let(:resource) do
      r = Vv::DependencyOrch::Resource.new(digest: floor, kind: :remote, index_digest: nil)
      r.observe(Vv::DependencyOrch::Placement.absent(kind: :registry, at: "ghcr.io", because: "no such manifest"))
      r.observe(Vv::DependencyOrch::Placement.absent(kind: :local_daemon, at: "local", because: "not held"))
      r
    end

    it "is a finding, because completed answers are evidence" do
      result = described_class.call(graph_with(resource))
      expect(result[:findings].map { |f| f[:finding] }).to eq([:declared_but_absent])
      expect(result[:unknown]).to be_empty
    end
  end

  # GATE: `unreachable` is not `absent`, at the report level.
  #
  # This is the one that keeps the tool trustworthy. A drift report is read as a
  # work list, so a finding that turns out to be "we could not check" costs a
  # trip and costs the tool its credibility.
  context "when nothing gave a completed answer" do
    let(:resource) do
      r = Vv::DependencyOrch::Resource.new(digest: floor, kind: :remote, index_digest: nil)
      r.observe(Vv::DependencyOrch::Placement.unreachable(kind: :registry, at: "ghcr.io", because: "401"))
      r.observe(Vv::DependencyOrch::Placement.never_looked(kind: :host, at: "sharedai.space"))
      r
    end

    it "reports unknown and finds nothing" do
      result = described_class.call(graph_with(resource))
      expect(result[:findings]).to be_empty
      expect(result[:unknown].length).to eq(1)
      expect(result[:unknown].first[:because]).to match(/1 unreachable, 1 never checked/)
    end
  end

  context "a resource nobody references" do
    it "cannot drift" do
      graph = Vv::DependencyOrch::Graph.new
      graph.add_resource(
        Vv::DependencyOrch::Resource.new(digest: floor, kind: :local, index_digest: false)
      )

      result = described_class.call(graph)
      expect(result[:findings]).to be_empty
      expect(result[:examined]).to eq(0)
    end
  end

  # THE FIRST REAL RUN GOT THIS WRONG, and it is the gem's central promise.
  #
  # 2026-09-13, pointed at magentic-stack: rust:1.96.1-bookworm@sha256:a339861a
  # came back as declared_but_absent. It is the index digest of a live Docker
  # Hub image, and `docker buildx imagetools inspect` resolves it fine. The only
  # placement checked was the LOCAL DAEMON, which had never pulled it -- and
  # "not on this machine" was counted as "not anywhere".
  #
  # That is the same index-miss-reads-like-evidence failure the whole model is
  # built against, one level up: absence was honest about its STATE and silent
  # about whether the answering placement was entitled to give it.
  context "a remote digest the local daemon has simply never pulled" do
    let(:rust) { "sha256:#{'a339861a' * 8}" }

    def declared_remote(&observe)
      r = Vv::DependencyOrch::Resource.new(
        digest: rust, kind: :remote, names: ["rust:1.96.1-bookworm"]
      )
      observe&.call(r)
      graph = Vv::DependencyOrch::Graph.new
      graph.add_resource(r)
      graph.add_edge(
        Vv::DependencyOrch::Edge.new(
          kind: :declares, from: "line:magentic-stack/gems/adapters/nemo-switchyard/Dockerfile#L12",
          to: rust,
          where: { repo: "magentic-stack", path: "gems/adapters/nemo-switchyard/Dockerfile", line: 12 },
          because: "digest-pinned image"
        )
      )
      described_class.call(graph)
    end

    it "is NOT a finding: the daemon cannot answer whether a remote digest exists" do
      result = declared_remote do |r|
        r.observe(Vv::DependencyOrch::Placement.absent(kind: :local_daemon, at: "local",
                                                       because: "the daemon listed every image it holds and this digest was not among them"))
      end

      expect(result[:findings]).to be_empty
    end

    it "says which placements spoke and why none of them counted" do
      result = declared_remote do |r|
        r.observe(Vv::DependencyOrch::Placement.absent(kind: :local_daemon, at: "local",
                                                       because: "the daemon listed every image it holds and this digest was not among them"))
      end

      because = result[:unknown].first[:because]
      expect(because).to include("no AUTHORITY")
      expect(because).to include("not-here, not gone")
    end

    it "IS a finding once the registry -- the authority -- says absent" do
      result = declared_remote do |r|
        r.observe(Vv::DependencyOrch::Placement.absent(kind: :local_daemon, at: "local",
                                                       because: "the daemon listed every image it holds and this digest was not among them"))
        r.observe(Vv::DependencyOrch::Placement.absent(kind: :registry, at: "docker.io",
                                                       because: "the registry completed a manifest request and answered not-found"))
      end

      expect(result[:findings].length).to eq(1)
      expect(result[:findings].first[:finding]).to eq(:declared_but_absent)
    end

    # The mirror case, so the rule is not just "ignore the daemon": for an image
    # that exists ONLY locally, the daemon IS the authority and its no counts.
    it "still trusts the daemon about a local-only image" do
      r = Vv::DependencyOrch::Resource.new(
        digest: "sha256:#{'beef0001' * 8}", kind: :local, names: ["built-here"], index_digest: true
      )
      r.observe(Vv::DependencyOrch::Placement.absent(kind: :local_daemon, at: "local",
                                                       because: "the daemon listed every image it holds and this digest was not among them"))
      graph = Vv::DependencyOrch::Graph.new
      graph.add_resource(r)
      graph.add_edge(
        Vv::DependencyOrch::Edge.new(
          kind: :references, from: "line:x/Dockerfile#L1", to: r.digest,
          where: { repo: "x", path: "Dockerfile", line: 1 }, because: "names it"
        )
      )

      result = described_class.call(graph)
      expect(result[:findings].first[:finding]).to eq(:declared_but_absent)
    end
  end
end
