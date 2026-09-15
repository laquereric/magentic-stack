# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

# `.cpcp/deploy.json` is WHEN local_deploy / remote_deploy. It is not
# compile or runtime protocol, and it is not a second pin index.
RSpec.describe Vv::DependencyOrch::Adapters::Deploy do
  let(:floor) { "sha256:#{'7e42440c' * 8}" }
  let(:ghcr)  { "sha256:#{'41b32898' * 8}" }
  let(:blob)  { "sha256:#{'b' * 64}" }

  def write_deploy(root, body)
    dir = File.join(root, ".cpcp")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "deploy.json"), JSON.pretty_generate(body))
  end

  def manifest(overrides = {})
    {
      "kind" => "cpcp-deploy",
      "version" => 1,
      "name" => "fixture-overlay",
      "not" => {
        "compile" => ".cpcp/package.json",
        "runtime_protocol" => ".cpcp/package.json"
      },
      "local_deploy" => {
        "images" => {
          "rails_floor" => {
            "name" => "mind-pod-rails-base",
            "digest" => floor,
            "index_digest" => false,
            "tag_for_humans" => "mind-pod-rails-base:1a89f67",
            "because" => "unpublished local FLOOR"
          }
        },
        "blobs" => {
          "kind" => "mmg-blob",
          "store" => "volume:data:/data/blobs.sqlite3",
          "required" => [blob]
        }
      },
      "remote_deploy" => {
        "images" => {
          "rails_floor" => {
            "name" => "ghcr.io/laquereric/magentic-stack/rails-base",
            "digest" => ghcr,
            "index_digest" => ghcr,
            "because" => "last public GHCR index; not the local FLOOR identity"
          }
        },
        "blobs" => { "kind" => "mmg-blob", "store" => "https://example.example/_cpcp", "required" => [] }
      }
    }.merge(overrides)
  end

  it "refuses a missing file as not_indexed, not as a crash" do
    Dir.mktmpdir do |root|
      result = described_class.new.load(root: root)
      expect(result[:ok]).to be false
      expect(result[:reason]).to eq("not_indexed")
      expect(result[:because]).to match(/deploy\.json/)
    end
  end

  it "refuses a package.json-shaped file so protocol and deploy stay apart" do
    Dir.mktmpdir do |root|
      write_deploy(root, "kind" => "cpcp-application", "version" => 1)
      result = described_class.new.load(root: root)
      expect(result[:ok]).to be false
      expect(result[:reason]).to eq("unsupported_kind")
      expect(result[:because]).to match(/compile and runtime protocol/)
    end
  end

  it "plants a tag in the digest field as tag_is_not_identity" do
    Dir.mktmpdir do |root|
      body = manifest
      body["local_deploy"]["images"]["rails_floor"]["digest"] = "rails-base:latest"
      write_deploy(root, body)
      result = described_class.new.load(root: root)
      expect(result[:ok]).to be false
      expect(result[:reason]).to eq("tag_is_not_identity")
    end
  end

  it "emits declares edges tagged with when, not a merged pin set" do
    Dir.mktmpdir do |root|
      write_deploy(root, manifest)
      result = described_class.new.load(root: root)
      expect(result[:ok]).to be true
      whens = result[:edges].map { |e| e.where[:when] }.uniq
      expect(whens).to contain_exactly(:local_deploy, :remote_deploy)
      expect(result[:edges].map(&:kind).uniq).to eq([:declares])
      expect(result[:edges].map(&:to)).to include(floor, ghcr, blob)
    end
  end

  it "keeps an unpublished floor as index_digest false, not a dropped key" do
    Dir.mktmpdir do |root|
      write_deploy(root, manifest)
      result = described_class.new.load(root: root)
      local = result[:resources].find { |r| r.digest == floor }
      expect(local.unpublished?).to be true
      expect(local.to_h[:index_digest]).to eq(false)
      expect(local.kind).to eq(:local)
    end
  end

  it "does not treat the GHCR index and the local FLOOR as one identity" do
    Dir.mktmpdir do |root|
      write_deploy(root, manifest)
      result = described_class.new.load(root: root)
      expect(result[:resources].map(&:digest).uniq).to include(floor, ghcr)
      expect(floor).not_to eq(ghcr)
    end
  end
end

RSpec.describe Vv::DependencyOrch::When do
  it "splits protocol from deploy" do
    expect(described_class::PROTOCOL).to contain_exactly(:compile, :runtime_protocol)
    expect(described_class::DEPLOY).to contain_exactly(:local_deploy, :remote_deploy)
    expect(described_class.protocol?(:compile)).to be true
    expect(described_class.deploy?(:local_deploy)).to be true
    expect(described_class.deploy?(:compile)).to be false
  end
end

RSpec.describe Vv::DependencyOrch::Deploy do
  let(:floor) { "sha256:#{'7e42440c' * 8}" }

  class FakeDaemon
    def initialize(present: [], unreachable: false)
      @present = present
      @unreachable = unreachable
    end

    def available? = !@unreachable

    def placement_for(ref)
      if @unreachable
        return Vv::DependencyOrch::Placement.unreachable(
          kind: :local_daemon, at: "local", because: "daemon down"
        )
      end
      if @present.include?(ref)
        Vv::DependencyOrch::Placement.present(kind: :local_daemon, at: "local")
      else
        Vv::DependencyOrch::Placement.absent(
          kind: :local_daemon, at: "local", because: "not here"
        )
      end
    end
  end

  def write_deploy(root)
    FileUtils.mkdir_p(File.join(root, ".cpcp"))
    File.write(
      File.join(root, ".cpcp", "deploy.json"),
      JSON.pretty_generate(
        "kind" => "cpcp-deploy",
        "version" => 1,
        "local_deploy" => {
          "images" => {
            "rails_floor" => {
              "name" => "mind-pod-rails-base",
              "digest" => floor,
              "index_digest" => false,
              "tag_for_humans" => "mind-pod-rails-base:1a89f67"
            }
          }
        }
      )
    )
  end

  it "is ready when the digest is on the daemon" do
    Dir.mktmpdir do |root|
      write_deploy(root)
      result = described_class.ready(root: root, daemon: FakeDaemon.new(present: [floor]))
      expect(result[:ok]).to be true
      expect(result[:missing]).to eq([])
    end
  end

  it "is ready when only the human tag is on the daemon" do
    Dir.mktmpdir do |root|
      write_deploy(root)
      result = described_class.ready(
        root: root,
        daemon: FakeDaemon.new(present: ["mind-pod-rails-base:1a89f67"])
      )
      expect(result[:ok]).to be true
    end
  end

  it "refuses unpublished-and-missing as undeployable, not absent" do
    Dir.mktmpdir do |root|
      write_deploy(root)
      result = described_class.ready(root: root, daemon: FakeDaemon.new(present: []))
      expect(result[:ok]).to be false
      expect(result[:reason]).to eq("undeployable")
      expect(result[:because]).to match(/unpublished/)
      expect(result[:missing].first[:index_digest]).to eq(false)
    end
  end

  it "does not call a missing image absent when the daemon is unreachable" do
    Dir.mktmpdir do |root|
      write_deploy(root)
      result = described_class.ready(root: root, daemon: FakeDaemon.new(unreachable: true))
      expect(result[:reason]).to eq("unreachable")
    end
  end

  # THE AUTHORITY BUG. remote_deploy asked the LOCAL daemon whether a GHCR
  # digest was present, and reported `undeployable` when it was not -- which it
  # never would be, because the machine was never the authority for a remote
  # placement. Measured against the real registry: the published index came
  # back present the moment the right adapter was asked.
  class FakeRegistry
    attr_reader :asked

    def initialize(present: [])
      @present = present
      @asked = []
    end

    def available? = true

    def placement_for(digest, at:, repository:)
      @asked << { digest: digest, at: at, repository: repository }
      if @present.include?(digest)
        Vv::DependencyOrch::Placement.present(kind: :registry, at: at)
      else
        Vv::DependencyOrch::Placement.absent(kind: :registry, at: at, because: "no manifest")
      end
    end
  end

  def write_remote(root, digest)
    FileUtils.mkdir_p(File.join(root, ".cpcp"))
    File.write(
      File.join(root, ".cpcp", "deploy.json"),
      JSON.pretty_generate(
        "kind" => "cpcp-deploy", "version" => 1,
        "remote_deploy" => {
          "images" => {
            "rails_floor" => {
              "name" => "ghcr.io/laquereric/magentic-stack/rails-base",
              "digest" => digest,
              "index_digest" => digest,
              "tag_for_humans" => "rails-base:latest"
            }
          }
        }
      )
    )
  end

  it "asks the registry about remote_deploy, and never the local daemon" do
    Dir.mktmpdir do |root|
      write_remote(root, floor)
      registry = FakeRegistry.new(present: [floor])
      daemon = FakeDaemon.new(present: [])   # would have said undeployable
      result = described_class.ready(root: root, placement: :remote_deploy,
                                     daemon: daemon, registry: registry)
      expect(result[:ok]).to be true
      expect(result[:missing]).to eq([])
      expect(registry.asked.length).to eq(1)
      expect(registry.asked.first[:at]).to eq("ghcr.io")
      expect(registry.asked.first[:repository]).to eq("ghcr.io/laquereric/magentic-stack/rails-base")
    end
  end

  it "names the registry, not the daemon, when a remote image is missing" do
    Dir.mktmpdir do |root|
      write_remote(root, floor)
      result = described_class.ready(root: root, placement: :remote_deploy,
                                     registry: FakeRegistry.new(present: []))
      expect(result[:ok]).to be false
      expect(result[:reason]).to eq("undeployable")
      expect(result[:because]).to match(/the registry/)
      expect(result[:because]).not_to match(/this daemon/)
    end
  end

  # A tag resolves to whatever was last pushed. Accepting it as evidence at a
  # registry would let a moved tag stand in for a digest that is not there.
  it "does not accept a human tag as remote evidence" do
    Dir.mktmpdir do |root|
      write_remote(root, floor)
      registry = FakeRegistry.new(present: ["rails-base:latest"])
      result = described_class.ready(root: root, placement: :remote_deploy, registry: registry)
      expect(result[:ok]).to be false
      expect(registry.asked.map { |a| a[:digest] }).to eq([floor])
    end
  end
end

RSpec.describe "inventory loads deploy declarations" do
  let(:floor) { "sha256:#{'7e42440c' * 8}" }

  it "adds deploy declares even when the pin index is absent" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, ".cpcp"))
      File.write(
        File.join(root, ".cpcp", "deploy.json"),
        JSON.pretty_generate(
          "kind" => "cpcp-deploy",
          "version" => 1,
          "local_deploy" => {
            "images" => {
              "rails_floor" => {
                "name" => "mind-pod-rails-base",
                "digest" => floor,
                "index_digest" => false
              }
            }
          }
        )
      )

      pins = instance_double(Vv::DependencyOrch::Adapters::Pins, available?: false)
      allow(Vv::DependencyOrch::Adapters::Pins).to receive(:unavailable_envelope)
        .and_return(Vv::DependencyOrch::Envelope.refuse("not_indexed", "no pin index"))

      inv = Vv::DependencyOrch::Inventory.new(roots: [root], local: false, pins: pins)
      graph = inv.build
      expect(graph[floor]).not_to be_nil
      expect(graph[floor].unpublished?).to be true
      expect(graph.declares_of(floor)).not_to be_empty
      expect(graph.declares_of(floor).first.where[:when]).to eq(:local_deploy)
    end
  end
end
