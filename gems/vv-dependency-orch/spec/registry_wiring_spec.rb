# frozen_string_literal: true

# THE REGISTRY IS THE ONLY AUTHORITY ON WHETHER A REMOTE DIGEST EXISTS.
#
# Until it was wired into the inventory, a clean drift report meant "nothing
# local contradicts the declarations" while reading as "everything checks out".
# Those are very different claims and only one of them is worth acting on.
#
# The wiring turned out to be mostly about NAMES. A registry cannot be asked
# about a bare digest -- `imagetools inspect` takes repository@digest -- so a
# digest whose declarations never gave it a repository is one nothing can
# resolve, and saying so is the honest answer rather than guessing a repository
# and manufacturing a false absence.
RSpec.describe "registry wiring" do
  let(:inventory) { Vv::DependencyOrch::Inventory.new(roots: []) }

  describe "repository derivation" do
    def repo_of(name) = inventory.send(:repository_of, name)

    # This is the case that was silently wrong for every tagged image. The pin
    # index captured `1.96.1-bookworm` as the NAME of rust:1.96.1-bookworm,
    # because its digest pattern excluded the colon -- so the repository asked
    # for was the tag, and the registry answered "insufficient_scope", which
    # arrives as unreachable and looks like a network problem.
    it "drops the tag, because the digest is already the identity" do
      expect(repo_of("rust:1.96.1-bookworm")).to eq("rust")
    end

    it "keeps a registry host and path intact" do
      expect(repo_of("ghcr.io/laquereric/magentic-stack/rails-base"))
        .to eq("ghcr.io/laquereric/magentic-stack/rails-base")
    end

    it "does not mistake a PORT for a tag" do
      # localhost:5000/x -- the last colon is a port, not a tag, and the
      # giveaway is the slash after it.
      expect(repo_of("localhost:5000/vv-canvas")).to eq("localhost:5000/vv-canvas")
    end

    it "drops a tag that follows a port" do
      expect(repo_of("localhost:5000/vv-canvas:0.1.0")).to eq("localhost:5000/vv-canvas")
    end

    it "has nothing to say about an empty name" do
      expect(repo_of("")).to be_nil
      expect(repo_of(nil)).to be_nil
    end
  end

  describe "which registry host is asked" do
    def host_of(repo) = inventory.send(:registry_host, repo)

    it "defaults an unqualified repository to docker.io" do
      expect(host_of("rust")).to eq("docker.io")
      expect(host_of("milvusdb/milvus")).to eq("docker.io")
    end

    it "uses the host when the repository names one" do
      expect(host_of("ghcr.io/laquereric/magentic-stack/rails-base")).to eq("ghcr.io")
    end
  end

  describe "a digest no declaration named" do
    # never_looked, NOT absent. There is no question to ask, and inventing a
    # repository to ask it with would be the same manufactured absence this gem
    # refuses everywhere else.
    it "is never_looked, and says why" do
      resource = Vv::DependencyOrch::Resource.new(
        digest: "sha256:#{'ab' * 32}", kind: :remote, names: []
      )
      placements = inventory.send(:registry_placements_for, resource)

      expect(placements.length).to eq(1)
      expect(placements.first.state).to eq(:not_indexed)
      expect(placements.first.because).to include("bare digest")
    end
  end
end
